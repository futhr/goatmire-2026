defmodule Goatmire.Diagnostics.Sampler do
  @moduledoc """
  Keeps a bounded, in-memory diagnostic history for BeamLens.

  Prometheus remains a useful scrape target, but an interactive diagnosis needs
  one coherent snapshot of application semantics, verifier evidence, ExMaude
  health, and the BEAM. This process samples those facts once per second and
  keeps five minutes. Nothing here can deploy rules or actuate a device.
  """

  use GenServer

  @sample_ms 1_000
  @history_limit 300
  @event_limit 50

  @events [
    [:goatmire, :engine, :event],
    [:goatmire, :engine, :alert],
    [:goatmire, :engine, :throttled],
    [:goatmire, :engine, :deploy],
    [:goatmire, :verify, :stop],
    [:goatmire, :storm, :tick],
    [:ex_maude, :pool, :checkout, :stop],
    [:ex_maude, :server, :start],
    [:ex_maude, :server, :timeout],
    [:ex_maude, :server, :crash]
  ]

  @counter_keys [:events, :alerts, :throttled, :maude_checkouts, :maude_timeouts, :maude_crashes]

  @doc "Starts the bounded in-memory sampler."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "Returns current evidence plus aggregates for a bounded recent window."
  @spec snapshot(10..300) :: map()
  def snapshot(window_seconds \\ 60) when window_seconds in 10..300 do
    GenServer.call(__MODULE__, {:snapshot, window_seconds})
  end

  @doc """
  Returns bounded per-second series for the metrics pane, oldest first.

  Same ring buffer the diagnostic snapshot reads, so charts and the BeamLens
  chat cite identical evidence.
  """
  @spec series(10..300) :: map()
  def series(window_seconds \\ 300) when window_seconds in 10..300 do
    GenServer.call(__MODULE__, {:series, window_seconds})
  end

  @doc "Forwards an attached telemetry event to the owning sampler process."
  @spec handle_telemetry([atom()], map(), map(), pid()) :: tuple()
  def handle_telemetry(event, measurements, metadata, pid) do
    send(pid, {:telemetry, event, measurements, metadata})
  end

  @impl true
  def init(opts) do
    sample_ms = Keyword.get(opts, :sample_ms, @sample_ms)
    history_limit = Keyword.get(opts, :history_limit, @history_limit)
    handler_id = "goatmire-diagnostics-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach_many(handler_id, @events, &__MODULE__.handle_telemetry/4, self())

    state = %{
      handler_id: handler_id,
      sample_ms: sample_ms,
      history_limit: history_limit,
      history: [],
      recent_events: [],
      totals: zero_totals(),
      previous_totals: zero_totals(),
      last_checkout_us: nil,
      server_starts: 0
    }

    schedule_sample(sample_ms)
    {:ok, take_sample(state)}
  end

  @impl true
  def terminate(_, state) do
    :telemetry.detach(state.handler_id)
    :ok
  end

  @impl true
  def handle_call({:snapshot, window_seconds}, _, state) do
    points = Enum.take(state.history, window_seconds)
    current = List.first(points) || %{}

    reply = %{
      captured_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      window_seconds: window_seconds,
      sample_count: length(points),
      current: current,
      window: summarize(points),
      recent_events: state.recent_events
    }

    {:reply, reply, state}
  end

  def handle_call({:series, window_seconds}, _, state) do
    points = state.history |> Enum.take(window_seconds) |> Enum.reverse()

    reply = %{
      captured_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      window_seconds: window_seconds,
      sample_count: length(points),
      current: List.last(points) || %{},
      series: %{
        events: series_of(points, &(get_in(&1, [:engine, :rates_per_second, :events]) || 0)),
        alerts: series_of(points, &(get_in(&1, [:engine, :rates_per_second, :alerts]) || 0)),
        throttled: series_of(points, &(get_in(&1, [:engine, :rates_per_second, :throttled]) || 0)),
        withheld: series_of(points, &get_in(&1, [:engine, :withheld])),
        maude_in_use: series_of(points, &Map.get(&1.maude.pool, :in_use, 0)),
        maude_checkout_us: series_of(points, & &1.maude.checkout_last_us),
        fleet: series_of(points, & &1.fleet.devices),
        run_queue: series_of(points, & &1.beam.run_queue),
        process_count: series_of(points, & &1.beam.process_count),
        memory_mb: series_of(points, &div(&1.beam.memory_bytes || 0, 1_048_576)),
        scheduler_pct: series_of(points, & &1.beam.scheduler_utilization_percent)
      }
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_info(:sample, state) do
    schedule_sample(state.sample_ms)
    {:noreply, take_sample(state)}
  end

  def handle_info({:telemetry, event, measurements, metadata}, state) do
    state = count_event(event, measurements, state)

    diagnostic_event = %{
      at: DateTime.utc_now() |> DateTime.to_iso8601(),
      event: Enum.join(event, "."),
      measurements: compact(measurements),
      metadata: compact(metadata)
    }

    {:noreply,
     %{
       state
       | recent_events: bounded_prepend(state.recent_events, diagnostic_event, @event_limit)
     }}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp take_sample(state) do
    engine = safe_engine_status()
    totals = state.totals
    active_run? = not is_nil(engine[:run_id])

    deltas =
      Map.new(
        @counter_keys,
        &{&1, max(Map.fetch!(totals, &1) - Map.fetch!(state.previous_totals, &1), 0)}
      )

    sample = %{
      captured_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      run_id: engine[:run_id],
      scenario: if(active_run?, do: compact(engine[:scenario])),
      mode: if(active_run?, do: engine[:mode]),
      engine: %{
        deployed: engine[:deployed_count] || 0,
        withheld: length(engine[:withheld] || []),
        things_seen: engine[:things_seen] || 0,
        counters: engine[:counters] || zero_engine_counters(),
        rates_per_second: Map.take(deltas, [:events, :alerts, :throttled]),
        recent_alerts: compact(engine[:recent_alerts] || [])
      },
      verification: compact_verification(engine[:verification]),
      maude: %{
        pool: safe_pool_status(),
        checkout_last_us: state.last_checkout_us,
        checkouts_per_second: deltas.maude_checkouts,
        timeouts_per_second: deltas.maude_timeouts,
        crashes_per_second: deltas.maude_crashes,
        server_starts: state.server_starts
      },
      fleet: %{devices: safe_fleet_count()},
      beam: beam_snapshot()
    }

    %{
      state
      | history: bounded_prepend(state.history, sample, state.history_limit),
        previous_totals: totals
    }
  end

  defp summarize([]) do
    %{
      alerts: 0,
      events: 0,
      throttled: 0,
      maude_checkouts: 0,
      maude_timeouts: 0,
      maude_crashes: 0
    }
  end

  defp summarize(points) do
    Enum.reduce(points, summarize([]), fn point, summary ->
      rates = get_in(point, [:engine, :rates_per_second]) || %{}
      maude = point.maude

      %{
        alerts: summary.alerts + Map.get(rates, :alerts, 0),
        events: summary.events + Map.get(rates, :events, 0),
        throttled: summary.throttled + Map.get(rates, :throttled, 0),
        maude_checkouts: summary.maude_checkouts + maude.checkouts_per_second,
        maude_timeouts: summary.maude_timeouts + maude.timeouts_per_second,
        maude_crashes: summary.maude_crashes + maude.crashes_per_second
      }
    end)
  end

  defp count_event([:goatmire, :engine, :event], measurements, state),
    do: add_total(state, :events, measurements[:count] || 1)

  defp count_event([:goatmire, :engine, :alert], measurements, state),
    do: add_total(state, :alerts, measurements[:count] || 1)

  defp count_event([:goatmire, :engine, :throttled], measurements, state),
    do: add_total(state, :throttled, measurements[:count] || 1)

  defp count_event([:ex_maude, :pool, :checkout, :stop], measurements, state) do
    duration_us =
      measurements
      |> Map.get(:duration, 0)
      |> System.convert_time_unit(:native, :microsecond)

    state
    |> add_total(:maude_checkouts, 1)
    |> Map.put(:last_checkout_us, duration_us)
  end

  defp count_event([:ex_maude, :server, :timeout], _, state),
    do: add_total(state, :maude_timeouts, 1)

  defp count_event([:ex_maude, :server, :crash], _, state),
    do: add_total(state, :maude_crashes, 1)

  defp count_event([:ex_maude, :server, :start], _, state),
    do: Map.update!(state, :server_starts, &(&1 + 1))

  defp count_event(_, _, state), do: state

  defp add_total(state, key, amount) do
    %{state | totals: Map.update!(state.totals, key, &(&1 + amount))}
  end

  defp compact_verification(nil), do: nil

  defp compact_verification(verification) do
    verdict = verification.verdict

    %{
      status: verdict.status,
      duration_us: verdict.duration_us,
      rule_count: verdict.rule_count,
      conflict_count: length(verdict.conflicts),
      conflict_types:
        verdict.conflicts
        |> Enum.map(&Map.get(&1, :type))
        |> Enum.uniq(),
      witness: compact(Enum.take(verdict.conflicts, 5)),
      reason: compact(verdict.reason),
      scope: verdict.scope,
      stats: compact(verification.stats),
      scenario: compact(verification.scenario),
      verified_at: verification.verified_at
    }
  end

  defp beam_snapshot do
    :erlang.system_flag(:scheduler_wall_time, true)

    {active, total} =
      :erlang.statistics(:scheduler_wall_time)
      |> Enum.reduce({0, 0}, fn {_, active, total}, {active_sum, total_sum} ->
        {active_sum + active, total_sum + total}
      end)

    scheduler_utilization =
      if total > 0, do: Float.round(active / total * 100, 2), else: nil

    %{
      run_queue: :erlang.statistics(:total_run_queue_lengths),
      process_count: :erlang.system_info(:process_count),
      memory_bytes: :erlang.memory(:total),
      scheduler_utilization_percent: scheduler_utilization
    }
  rescue
    _ ->
      %{run_queue: nil, process_count: nil, memory_bytes: nil, scheduler_utilization_percent: nil}
  end

  defp safe_engine_status do
    Goatmire.Engine.status()
  catch
    :exit, _ -> %{}
  end

  defp safe_fleet_count do
    Goatmire.Fleet.count()
  rescue
    _ -> 0
  catch
    :exit, _ -> 0
  end

  defp safe_pool_status do
    ExMaude.Pool.status()
  rescue
    _ -> %{size: 0, overflow: 0, available: 0, in_use: 0, state: :unavailable}
  catch
    :exit, _ -> %{size: 0, overflow: 0, available: 0, in_use: 0, state: :unavailable}
  end

  defp compact(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> compact()
  end

  defp compact(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, compact(value)} end)

  defp compact(list) when is_list(list), do: Enum.map(list, &compact/1)

  defp compact(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> compact()
  end

  defp compact(pid) when is_pid(pid), do: inspect(pid)
  defp compact(reference) when is_reference(reference), do: inspect(reference)
  defp compact(nil), do: nil
  defp compact(value) when is_atom(value) or is_binary(value) or is_number(value), do: value
  defp compact(value), do: inspect(value)

  defp series_of(points, fun), do: Enum.map(points, &(fun.(&1) || 0))

  defp bounded_prepend(list, item, limit), do: Enum.take([item | list], limit)
  defp zero_engine_counters, do: %{events: 0, alerts: 0, throttled: 0}
  defp zero_totals, do: Map.new(@counter_keys, &{&1, 0})
  defp schedule_sample(sample_ms), do: Process.send_after(self(), :sample, sample_ms)
end
