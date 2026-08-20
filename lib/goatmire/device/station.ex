defmodule Goatmire.Device.Station do
  @moduledoc """
  A fixed installation — conveyor, cold-store door, charger bay — rather than a
  vehicle.

  With only AGVs on the floor a gated storm produces zero alerts, which
  overstates what the gate does: it silences self-inflicted noise, not the
  operational alerts. These drive the properties `Goatmire.Rules.clean_set/0`
  is bound to, on the same deadband contract as `Goatmire.Device.Simulated`.
  """

  use GenServer, restart: :transient

  alias Goatmire.Transport

  @default_tick_ms 1_000
  @heartbeat_ticks 30

  # thing_id => {property, base, jitter, spike_chance, spike_delta, deadband}
  @profiles %{
    "conveyor-3" => {"torque_nm", 120.0, 8.0, 0.04, 90.0, 5.0},
    "door-cold-1" => {"open_seconds", 20.0, 15.0, 0.05, 130.0, 10.0},
    "charger-2" => {"cell_temp_c", 32.0, 3.0, 0.03, 18.0, 1.0},
    "station-11" => {"idle_minutes", 4.0, 4.0, 0.05, 14.0, 1.0},
    "dock-19" => {"occupied", nil, nil, nil, nil, nil}
  }

  @doc "The Things this module can model — the same set `clean_set/0` binds to."
  @spec known() :: [String.t()]
  def known, do: Map.keys(@profiles)

  @doc "Builds the transient child specification keyed by station Thing ID."
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    thing_id = Keyword.fetch!(opts, :thing_id)

    %{
      id: {__MODULE__, thing_id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      type: :worker
    }
  end

  @doc "Starts one simulated fixed station."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    thing_id = Keyword.fetch!(opts, :thing_id)
    GenServer.start_link(__MODULE__, opts, name: via(thing_id))
  end

  defp via(thing_id) do
    {:via, Registry, {Goatmire.Fleet.registry(), thing_id, %{kind: :station}}}
  end

  @impl true
  def init(opts) do
    thing_id = Keyword.fetch!(opts, :thing_id)
    tick_ms = Keyword.get(opts, :tick_ms, @default_tick_ms)

    profile = Map.get(@profiles, thing_id) || {"value", 50.0, 5.0, 0.03, 40.0, 2.0}

    state = %{
      thing_id: thing_id,
      profile: profile,
      value: elem(profile, 1),
      occupied: false,
      tick_ms: tick_ms,
      ticks: 0,
      reported: nil
    }

    if tick_ms > 0, do: schedule(tick_ms)
    {:ok, state}
  end

  @impl true
  def handle_call(:snapshot, _, state), do: {:reply, snapshot(state), state}

  @impl true
  def handle_info(:tick, state) do
    state =
      state
      |> Map.update!(:ticks, &(&1 + 1))
      |> step()
      |> report()

    if state.tick_ms > 0, do: schedule(state.tick_ms)
    {:noreply, state}
  end

  def handle_info({:instruct, _}, state), do: {:noreply, state}
  def handle_info(_, state), do: {:noreply, state}

  defp step(%{thing_id: "dock-19"} = state) do
    if :rand.uniform() < 0.08, do: %{state | occupied: not state.occupied}, else: state
  end

  defp step(%{profile: {_, base, jitter, spike_chance, spike_delta, _}} = state) do
    drift = (:rand.uniform() - 0.5) * jitter
    spike = if :rand.uniform() < spike_chance, do: spike_delta, else: 0.0

    # Pull toward baseline so the series wanders rather than random-walks away.
    pull = (base - state.value) * 0.15

    %{state | value: max(0.0, state.value + drift + spike + pull)}
  end

  defp report(%{thing_id: "dock-19"} = state) do
    if state.reported != state.occupied or heartbeat?(state) do
      Transport.publish_telemetry(state.thing_id, "occupied", state.occupied)
      %{state | reported: state.occupied}
    else
      state
    end
  end

  defp report(%{profile: {property, _, _, _, _, deadband}} = state) do
    if state.reported == nil or heartbeat?(state) or
         abs(state.value - state.reported) >= deadband do
      Transport.publish_telemetry(state.thing_id, property, Float.round(state.value, 1))
      %{state | reported: state.value}
    else
      state
    end
  end

  defp heartbeat?(state), do: rem(state.ticks, @heartbeat_ticks) == 0

  defp snapshot(%{thing_id: "dock-19"} = state) do
    base_snapshot(state) |> Map.put(:value, state.occupied)
  end

  defp snapshot(state), do: Map.put(base_snapshot(state), :value, Float.round(state.value, 1))

  defp base_snapshot(state) do
    %{
      thing_id: state.thing_id,
      kind: :station,
      status: :online,
      battery: nil,
      zone: nil,
      mode: nil,
      destination: nil
    }
  end

  defp schedule(tick_ms), do: Process.send_after(self(), :tick, tick_ms)
end
