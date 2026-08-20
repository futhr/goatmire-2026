defmodule Goatmire.Scenario.Storm do
  @moduledoc """
  The alert-storm beat, against the live fleet.

  Boots devices, deploys a rule set through `Goatmire.Engine`, stages a shift
  change, and reads the engine's counters. Run twice — observe, then enforce —
  the only difference is which rules were allowed to deploy.

  A shift change is two things at once: the clock rolls into shift hours
  (arming the Zone-7 rule) and a batch of AGVs crosses the low-battery
  threshold (arming the reroute rule).

  Counters are this simulator's output at the configured fleet size and tick
  rate — not a benchmark, not an incident. Read the screen on the day.
  """

  alias Goatmire.{Engine, Fleet, Rules}

  @pubsub Goatmire.PubSub
  @topic "goatmire:storm"

  @default_fleet 200
  @default_duration 60
  @default_tick_ms 250
  @default_drain_pct 18
  @default_shift_hour 9

  @type summary :: %{
          mode: Goatmire.Engine.gate_mode(),
          fleet_size: non_neg_integer(),
          duration_seconds: pos_integer(),
          rules_deployed: non_neg_integer(),
          rules_withheld: [String.t()],
          verdict: Goatmire.Verifier.Verdict.t(),
          events: non_neg_integer(),
          alerts: non_neg_integer(),
          throttled: non_neg_integer(),
          wall_clock_ms: non_neg_integer()
        }

  @doc "PubSub topic carrying per-second storm frames."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc """
  Runs one storm.

  ## Options

    * `:mode` — `:observe` records the verdict but permits the simulated
      conflict; `:enforce` withholds it (default `:enforce`)
    * `:fleet_size` — simulated AGVs to boot (default `#{@default_fleet}`)
    * `:duration_seconds` — how long to observe (default `#{@default_duration}`)
    * `:tick_ms` — device physics tick; lower means denser telemetry
      (default `#{@default_tick_ms}`)
    * `:drain_pct` — battery level the fleet is dropped to (default `#{@default_drain_pct}`)
    * `:keep_fleet` — leave the devices running afterwards (default `false`)
  """
  @spec run(keyword()) :: {:ok, summary()}
  def run(opts \\ []) do
    mode = mode_from_opts(opts)
    fleet_size = Keyword.get(opts, :fleet_size, @default_fleet)
    duration = Keyword.get(opts, :duration_seconds, @default_duration)
    tick_ms = Keyword.get(opts, :tick_ms, @default_tick_ms)
    drain_pct = Keyword.get(opts, :drain_pct, @default_drain_pct)
    validate_options!(fleet_size, duration, tick_ms, drain_pct)

    corpus = Rules.fleet(fleet_size) ++ Rules.clean_set()

    Fleet.stop_all()
    {:ok, _} = Fleet.start_simulated_fleet(fleet_size, tick_ms: tick_ms)
    # Operational traffic that should still reach a human when the gate is on.
    {:ok, _} = Fleet.start_stations(tick_ms: tick_ms)
    # Full reset: a leftover world would suppress rules that should fire.
    :ok = Engine.reset()

    {:ok, deployment} = Engine.deploy(corpus, mode: mode, scenario: {:storm, mode})

    broadcast({:storm_started, Map.merge(deployment, %{fleet_size: fleet_size, mode: mode})})

    started_at = System.monotonic_time(:millisecond)
    stage_shift_change(drain_pct)
    observe(duration, mode)
    wall_clock_ms = System.monotonic_time(:millisecond) - started_at

    status = Engine.status()
    unless Keyword.get(opts, :keep_fleet, false), do: Fleet.stop_all()

    summary = %{
      mode: mode,
      fleet_size: fleet_size,
      duration_seconds: duration,
      rules_deployed: deployment.deployed,
      rules_withheld: deployment.withheld,
      verdict: deployment.verdict,
      events: status.counters.events,
      alerts: status.counters.alerts,
      throttled: status.counters.throttled,
      wall_clock_ms: wall_clock_ms
    }

    broadcast({:storm_finished, summary})
    {:ok, summary}
  end

  @doc """
  Runs the same shift change twice — observe-only, then enforced.

  Returns both summaries plus the ratio between them, computed from the
  measured counters rather than asserted.
  """
  @spec compare(keyword()) ::
          {:ok,
           %{
             observed: summary(),
             enforced: summary(),
             ratio: float() | nil
           }}
  def compare(opts \\ []) do
    {:ok, observed} = run(Keyword.put(opts, :mode, :observe))
    {:ok, enforced} = run(Keyword.put(opts, :mode, :enforce))

    ratio =
      case enforced.alerts do
        0 -> nil
        n -> Float.round(observed.alerts / n, 1)
      end

    {:ok,
     %{
       observed: observed,
       enforced: enforced,
       ratio: ratio
     }}
  end

  defp stage_shift_change(drain_pct) do
    Fleet.instruct_all({:set_hour, @default_shift_hour})
    Fleet.instruct_all({:drain_to, drain_pct})
    :ok
  end

  defp observe(duration, mode) do
    _ =
      Enum.reduce(1..duration, %{alerts: 0, events: 0}, fn second, previous ->
        Process.sleep(1_000)
        counters = Engine.status().counters

        frame = %{
          mode: mode,
          second: second,
          duration: duration,
          events_total: counters.events,
          alerts_total: counters.alerts,
          throttled_total: counters.throttled,
          events_this_second: counters.events - previous.events,
          alerts_this_second: counters.alerts - previous.alerts
        }

        :telemetry.execute(
          [:goatmire, :storm, :tick],
          %{
            events: frame.events_this_second,
            alerts: frame.alerts_this_second,
            alerts_total: counters.alerts
          },
          %{mode: mode, second: second}
        )

        broadcast({:storm_tick, frame})
        %{alerts: counters.alerts, events: counters.events}
      end)

    :ok
  end

  defp mode_from_opts(opts) do
    case Keyword.get(opts, :mode, :enforce) do
      mode when mode in [:observe, :enforce] -> mode
      other -> raise ArgumentError, "invalid storm mode: #{inspect(other)}"
    end
  end

  defp validate_options!(fleet_size, duration, tick_ms, drain_pct) do
    validate_positive_integer!(fleet_size, :fleet_size)
    validate_positive_integer!(duration, :duration_seconds)
    validate_positive_integer!(tick_ms, :tick_ms)

    unless is_number(drain_pct) and drain_pct >= 0 and drain_pct <= 100 do
      raise ArgumentError, "drain_pct must be a number between 0 and 100"
    end
  end

  defp validate_positive_integer!(value, name) do
    unless is_integer(value) and value > 0 do
      raise ArgumentError, "#{name} must be a positive integer"
    end
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, message)
  catch
    :exit, _ -> :ok
  end
end
