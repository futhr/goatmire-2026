defmodule Goatmire.Engine do
  @moduledoc """
  Telemetry in, actuation out. Subscribes to every device's readings over
  `Goatmire.Transport`, evaluates deployed rules with
  `Goatmire.Engine.RuleEval`, and publishes commands back — so the loop closes
  through the transport and the device rather than inside one function.

  `deploy/2` is the only way rules enter. It verifies first. In `:observe`
  mode a conflict is recorded but allowed to run in the simulation; in
  `:enforce` mode every rule named in a conflict is withheld. `:unverified`
  deploys nothing in either mode.

  Actuation is bounded at `max_commands_per_window` per Thing per `window_ms`;
  beyond that commands are dropped and counted, so an oscillating rule pair
  degrades noisily instead of melting the node.

  Emits `[:goatmire, :engine, :event | :alert | :throttled | :deploy]`.
  """

  use GenServer

  require Logger

  alias Goatmire.{Engine.RuleEval, Gate, Transport, Transport.Local, Verifier}

  @pubsub Goatmire.PubSub
  @topic "goatmire:engine"

  @default_window_ms 10_000
  @default_max_commands 20
  @recent_alert_limit 12
  @observed_thing_limit 500

  @type counters :: %{
          events: non_neg_integer(),
          alerts: non_neg_integer(),
          throttled: non_neg_integer()
        }

  @type gate_mode :: :observe | :enforce

  @doc "PubSub topic carrying engine frames to LiveViews and Livebooks."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc "Starts the rule engine under its registered name."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Verifies a candidate rule set and deploys what survives.

  `mode: :observe` deploys despite conflicts; the verdict is still computed
  and reported. `mode: :enforce` withholds conflicts. An `:unverified` set
  never deploys.
  """
  @spec deploy([map()], keyword()) ::
          {:ok,
           %{
             verdict: Verifier.Verdict.t(),
             deployed: non_neg_integer(),
             withheld: [String.t()],
             mode: gate_mode(),
             run_id: String.t(),
             verification: map()
           }}
  def deploy(rules, opts \\ []) do
    GenServer.call(__MODULE__, {:deploy, rules, opts}, 60_000)
  end

  @doc "Removes every deployed rule. Devices keep running; nothing actuates them."
  @spec undeploy() :: :ok
  def undeploy, do: GenServer.call(__MODULE__, :undeploy)

  @doc "Current counters, deployed rule ids, and the last verdict."
  @spec status() :: map()
  def status, do: GenServer.call(__MODULE__, :status)

  @doc "The exact rule terms currently evaluated by the engine."
  @spec deployed_rules() :: [map()]
  def deployed_rules, do: GenServer.call(__MODULE__, :deployed_rules)

  @doc "Zeroes the counters without changing the deployed rule set."
  @spec reset_counters() :: :ok
  def reset_counters, do: GenServer.call(__MODULE__, :reset_counters)

  @doc """
  Forgets everything observed: counters, throttle windows, and the world.

  Use this rather than `reset_counters/0` between storm runs — a leftover world
  suppresses rules that should fire and the comparison measures stale state.
  """
  @spec reset() :: :ok
  def reset, do: GenServer.call(__MODULE__, :reset)

  @doc "The engine's view of a Thing's reported properties."
  @spec properties(String.t()) :: map()
  def properties(thing_id), do: GenServer.call(__MODULE__, {:properties, thing_id})

  @impl true
  def init(opts) do
    :ok = Transport.subscribe_all_telemetry()

    {:ok,
     %{
       rules: [],
       index: %{},
       world: %{},
       verdict: nil,
       mode: :enforce,
       withheld: [],
       verification: nil,
       scenario: nil,
       run_id: nil,
       counters: zero_counters(),
       recent_alerts: [],
       window_ms: Keyword.get(opts, :window_ms, @default_window_ms),
       max_commands: Keyword.get(opts, :max_commands_per_window, @default_max_commands),
       command_log: %{}
     }}
  end

  @impl true
  def handle_call({:deploy, rules, opts}, _, state) do
    mode = deployment_mode(opts)
    scenario = Keyword.get(opts, :scenario, :deploy)
    run_id = Keyword.get_lazy(opts, :run_id, &new_run_id/0)

    # Partitioned always: a whole-corpus reduction of 85 rules exceeds the
    # backend timeout and returns :unverified.
    {:ok, verdict, stats} = Gate.verify_partitioned(rules, scenario: scenario)

    %{admitted: admitted, withheld: withheld} =
      if mode == :enforce do
        Gate.split_on_verdict(rules, verdict)
      else
        # Even observe-only simulation does not turn absence of a verdict into
        # permission to activate.
        case verdict.status do
          :unverified -> %{admitted: [], withheld: rules}
          _ -> %{admitted: rules, withheld: []}
        end
      end

    verification = %{
      verdict: verdict,
      stats: stats,
      scenario: scenario,
      verified_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    :telemetry.execute(
      [:goatmire, :engine, :deploy],
      %{
        deployed: length(admitted),
        withheld: length(withheld),
        partitions: stats.partitions,
        pairs_considered: stats.pairs_considered,
        pairs_skipped: stats.pairs_skipped
      },
      %{status: verdict.status, mode: mode, scenario: scenario, run_id: run_id}
    )

    state = %{
      state
      | rules: admitted,
        index: RuleEval.index(admitted),
        verdict: verdict,
        mode: mode,
        withheld: rule_ids(withheld),
        verification: verification,
        scenario: scenario,
        run_id: run_id
    }

    result = %{
      verdict: verdict,
      deployed: length(admitted),
      withheld: rule_ids(withheld),
      mode: mode,
      verification: verification,
      run_id: run_id
    }

    broadcast({:engine_deployed, result})
    {:reply, {:ok, result}, state}
  end

  def handle_call(:undeploy, _, state) do
    {:reply, :ok,
     %{
       state
       | rules: [],
         index: %{},
         withheld: [],
         verdict: nil,
         verification: nil,
         scenario: nil,
         run_id: nil
     }}
  end

  def handle_call(:status, _, state), do: {:reply, public_status(state), state}

  def handle_call(:deployed_rules, _, state), do: {:reply, state.rules, state}

  def handle_call(:reset_counters, _, state) do
    {:reply, :ok, %{state | counters: zero_counters(), command_log: %{}, recent_alerts: []}}
  end

  def handle_call(:reset, _, state) do
    {:reply, :ok,
     %{state | counters: zero_counters(), command_log: %{}, world: %{}, recent_alerts: []}}
  end

  def handle_call({:properties, thing_id}, _, state) do
    {:reply, Map.get(state.world, thing_id, %{}), state}
  end

  @impl true
  def handle_info({:goatmire_publish, _, _} = message, state) do
    case Local.accept(message) do
      {:ok, _, payload} -> {:noreply, ingest(payload, state)}
      :ignore -> {:noreply, state}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  defp ingest(payload, state) do
    case Transport.decode_event(payload) do
      {:ok, event} -> handle_event(event, state)
      :error -> state
    end
  end

  defp handle_event(%{thing_id: thing_id, property: property, value: value}, state) do
    :telemetry.execute([:goatmire, :engine, :event], %{count: 1}, %{thing_id: thing_id})

    world = RuleEval.put_reading(state.world, thing_id, property, value)
    state = %{state | world: world, counters: bump(state.counters, :events)}

    {fired, actions} = RuleEval.evaluate(state.index, thing_id, world)

    if fired == [] do
      state
    else
      Enum.reduce(actions, state, &perform(&1, thing_id, &2))
    end
  end

  # Only a change is an alert; re-asserting a held value is not an incident.
  defp perform({:set_prop, target_thing, property, value}, _, state) do
    if RuleEval.get_reading(state.world, target_thing, property) == value do
      state
    else
      actuate(target_thing, property, value, state)
    end
  end

  defp perform({:set_env, property, value}, _, state) do
    world = RuleEval.put_reading(state.world, "__env__", property, value)
    alert(%{state | world: world}, "__env__", property, value)
  end

  defp perform({:invoke, target_thing, action}, _, state) do
    alert(state, target_thing, "invoke", action)
  end

  defp perform(_, _, state), do: state

  defp actuate(thing_id, property, value, state) do
    case throttle(state, thing_id) do
      {:ok, state} ->
        Transport.publish_command(thing_id, property, value)
        world = RuleEval.put_reading(state.world, thing_id, property, value)
        alert(%{state | world: world}, thing_id, property, value)

      {:throttled, state} ->
        :telemetry.execute([:goatmire, :engine, :throttled], %{count: 1}, %{thing_id: thing_id})
        counters = bump(state.counters, :throttled)
        broadcast({:engine_throttled, %{thing_id: thing_id, property: property}})
        %{state | counters: counters}
    end
  end

  defp alert(state, thing_id, property, value) do
    :telemetry.execute([:goatmire, :engine, :alert], %{count: 1}, %{
      thing_id: thing_id,
      property: property
    })

    counters = bump(state.counters, :alerts)

    alert = %{thing_id: thing_id, property: property, value: value, total: counters.alerts}

    broadcast({:engine_alert, alert})

    %{
      state
      | counters: counters,
        recent_alerts: Enum.take([alert | state.recent_alerts], @recent_alert_limit)
    }
  end

  defp throttle(state, thing_id) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - state.window_ms

    recent =
      state.command_log
      |> Map.get(thing_id, [])
      |> Enum.take_while(&(&1 > cutoff))

    if length(recent) >= state.max_commands do
      {:throttled, %{state | command_log: Map.put(state.command_log, thing_id, recent)}}
    else
      {:ok, %{state | command_log: Map.put(state.command_log, thing_id, [now | recent])}}
    end
  end

  defp public_status(state) do
    %{
      deployed_rules: Enum.map(state.rules, & &1.id),
      deployed_count: length(state.rules),
      withheld: state.withheld,
      mode: state.mode,
      verdict: state.verdict,
      verification: state.verification,
      scenario: state.scenario,
      run_id: state.run_id,
      counters: state.counters,
      recent_alerts: state.recent_alerts,
      things_seen: map_size(Map.delete(state.world, "__env__")),
      observed_things: observed_things(state.world)
    }
  end

  # The dashboard needs a view across the MQTT boundary, not just processes
  # supervised on the engine node. Keep the public snapshot deterministic and
  # bounded so a large fleet cannot turn a one-second refresh into a huge DOM.
  defp observed_things(world) do
    world
    |> Map.delete("__env__")
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.take(@observed_thing_limit)
    |> Enum.map(fn {thing_id, properties} ->
      %{thing_id: thing_id, properties: properties}
    end)
  end

  defp zero_counters, do: %{events: 0, alerts: 0, throttled: 0}
  defp bump(counters, key), do: Map.update!(counters, key, &(&1 + 1))

  defp deployment_mode(opts) do
    case Keyword.get(opts, :mode, :enforce) do
      mode when mode in [:observe, :enforce] -> mode
      other -> raise ArgumentError, "invalid deployment mode: #{inspect(other)}"
    end
  end

  defp new_run_id do
    "run-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
  end

  defp rule_ids(rules) do
    rules
    |> Enum.with_index(1)
    |> Enum.map(fn
      {%{id: id}, _} when is_binary(id) and id != "" -> id
      {_, index} -> "invalid-rule-#{index}"
    end)
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, message)
  catch
    :exit, _ -> :ok
  end
end
