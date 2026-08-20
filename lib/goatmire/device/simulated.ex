defmodule Goatmire.Device.Simulated do
  @moduledoc """
  A simulated AGV: charge that depletes while driving and recovers on a dock,
  a position it moves through at finite speed, and a shift clock.

  Reports on a deadband plus a periodic heartbeat, the way field devices do, so
  the engine sees telemetry with realistic burstiness rather than a metronome.

  Subscribes to `goatmire/things/<thing_id>/command`; a `destination` command
  starts a drive. Optionally also publishes VDA 5050 `state` (`vda5050: true`).

  It is a plausible mobile robot, not a model of any specific vehicle.
  """

  use GenServer, restart: :transient

  alias Goatmire.{Protocol.VDA5050, Transport, Transport.Local, Warehouse}

  @default_tick_ms 1_000
  @default_speed_mps 1.4
  @battery_deadband 1.0
  @position_deadband 1.0
  @heartbeat_ticks 30
  @drive_drain_per_s 0.05
  @idle_drain_per_s 0.004
  @charge_per_s 0.6
  @charged_pct 95.0

  @type state :: %{
          thing_id: String.t(),
          battery: float(),
          position: {number(), number()},
          destination: String.t() | nil,
          mode: :idle | :driving | :charging,
          hour: non_neg_integer(),
          speed_mps: float(),
          tick_ms: pos_integer(),
          ticks: non_neg_integer(),
          reported: map()
        }

  @doc "Builds the transient child specification keyed by simulated Thing ID."
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

  @doc "Starts one deterministic simulated AGV."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    thing_id = Keyword.fetch!(opts, :thing_id)
    GenServer.start_link(__MODULE__, opts, name: via(thing_id))
  end

  defp via(thing_id) do
    {:via, Registry, {Goatmire.Fleet.registry(), thing_id, %{kind: :simulated}}}
  end

  @impl true
  def init(opts) do
    thing_id = Keyword.fetch!(opts, :thing_id)
    tick_ms = Keyword.get(opts, :tick_ms, @default_tick_ms)

    :ok = Transport.subscribe_commands(thing_id)

    state = %{
      thing_id: thing_id,
      battery: Keyword.get(opts, :battery, initial_battery(thing_id)),
      position: Warehouse.home_position(thing_id),
      destination: nil,
      mode: :idle,
      hour: Keyword.get(opts, :hour, 8),
      speed_mps: Keyword.get(opts, :speed_mps, @default_speed_mps),
      tick_ms: tick_ms,
      ticks: 0,
      reported: %{},
      vda5050: Keyword.get(opts, :vda5050, false),
      vda_header_id: 0
    }

    if state.vda5050, do: announce_online(state)
    if tick_ms > 0, do: schedule(tick_ms)
    {:ok, state}
  end

  # A real vehicle registers a Last Will here. A simulated fleet shares one MQTT
  # session and cannot, so the bridge's liveness deadline covers it instead.
  defp announce_online(state) do
    Transport.impl().publish(
      VDA5050.topic(state.thing_id, :connection),
      VDA5050.connection(state.thing_id, :online, 0)
    )
  end

  # Staggered so a shift change does not cross the threshold on one tick.
  defp initial_battery(thing_id) do
    35.0 + :erlang.phash2(thing_id, 5_500) / 100.0
  end

  @impl true
  def handle_call(:snapshot, _, state) do
    {:reply, snapshot(state), state}
  end

  @impl true
  def handle_info(:tick, state) do
    state =
      state
      |> Map.update!(:ticks, &(&1 + 1))
      |> step()
      |> report()
      |> report_vda5050()

    if state.tick_ms > 0, do: schedule(state.tick_ms)
    {:noreply, state}
  end

  def handle_info({:goatmire_publish, _, _} = message, state) do
    case Local.accept(message) do
      {:ok, _, payload} -> {:noreply, apply_command(payload, state)}
      :ignore -> {:noreply, state}
    end
  end

  # Scenario staging; simulated devices only.
  def handle_info({:instruct, {:set_battery, pct}}, state) do
    {:noreply, %{state | battery: clamp(pct, 0.0, 100.0)}}
  end

  def handle_info({:instruct, {:set_hour, hour}}, state) do
    {:noreply, %{state | hour: hour}}
  end

  def handle_info({:instruct, {:drain_to, pct}}, state) do
    {:noreply, %{state | battery: min(state.battery, pct * 1.0)}}
  end

  def handle_info({:instruct, _}, state), do: {:noreply, state}
  def handle_info(_, state), do: {:noreply, state}

  defp step(%{mode: :driving} = state) do
    seconds = state.tick_ms / 1_000
    target = Warehouse.dock_position(state.destination)

    case target do
      nil ->
        %{state | mode: :idle, destination: nil}

      target ->
        {position, arrived?} = advance(state.position, target, state.speed_mps * seconds)
        battery = clamp(state.battery - @drive_drain_per_s * seconds, 0.0, 100.0)
        mode = if arrived?, do: :charging, else: :driving
        %{state | position: position, battery: battery, mode: mode}
    end
  end

  defp step(%{mode: :charging} = state) do
    seconds = state.tick_ms / 1_000
    battery = clamp(state.battery + @charge_per_s * seconds, 0.0, 100.0)
    mode = if battery >= @charged_pct, do: :idle, else: :charging
    %{state | battery: battery, mode: mode}
  end

  defp step(state) do
    seconds = state.tick_ms / 1_000
    %{state | battery: clamp(state.battery - @idle_drain_per_s * seconds, 0.0, 100.0)}
  end

  defp advance({x, y}, {tx, ty}, step_m) do
    dx = tx - x
    dy = ty - y
    distance = :math.sqrt(dx * dx + dy * dy)

    if distance <= step_m or distance == 0.0 do
      {{tx, ty}, true}
    else
      ratio = step_m / distance
      {{x + dx * ratio, y + dy * ratio}, false}
    end
  end

  defp report(state) do
    heartbeat? = rem(state.ticks, @heartbeat_ticks) == 0

    state
    |> maybe_report(:battery, state.battery, @battery_deadband, heartbeat?)
    |> maybe_report(:position, state.position, @position_deadband, heartbeat?)
    |> maybe_report(:hour, state.hour, 0, heartbeat?)
    |> maybe_report(:zone, Warehouse.zone_of(state.position), 0, heartbeat?)
    |> maybe_report(:mode, state.mode, 0, heartbeat?)
    |> maybe_report(:destination, state.destination, 0, heartbeat?)
  end

  # Full snapshot on a fixed cadence, not a deadband: master control times out
  # on it, which is what makes the bridge's CONNECTIONBROKEN deadline work.
  defp report_vda5050(%{vda5050: false} = state), do: state

  defp report_vda5050(state) do
    Transport.impl().publish(
      VDA5050.topic(state.thing_id, :state),
      VDA5050.state(state.thing_id, state, state.vda_header_id)
    )

    %{state | vda_header_id: state.vda_header_id + 1}
  end

  # Publishing nil would make "never set" indistinguishable from "set to nothing".
  defp maybe_report(state, _, nil, _, _), do: state

  defp maybe_report(state, property, value, deadband, heartbeat?) do
    previous = Map.get(state.reported, property)

    if heartbeat? or beyond_deadband?(previous, value, deadband) do
      publish(state.thing_id, property, value)
      %{state | reported: Map.put(state.reported, property, value)}
    else
      state
    end
  end

  defp beyond_deadband?(nil, _, _), do: true

  defp beyond_deadband?({px, py}, {x, y}, deadband) do
    :math.sqrt(:math.pow(x - px, 2) + :math.pow(y - py, 2)) >= deadband
  end

  defp beyond_deadband?(previous, value, deadband)
       when is_number(previous) and is_number(value) do
    abs(value - previous) >= deadband
  end

  defp beyond_deadband?(previous, value, _), do: previous != value

  defp publish(thing_id, :battery, value),
    do: Transport.publish_telemetry(thing_id, "battery", Float.round(value * 1.0, 1))

  defp publish(thing_id, :position, {x, y}) do
    Transport.publish_telemetry(thing_id, "position", %{
      "x" => Float.round(x * 1.0, 2),
      "y" => Float.round(y * 1.0, 2)
    })
  end

  defp publish(thing_id, property, value),
    do: Transport.publish_telemetry(thing_id, to_string(property), value)

  defp apply_command(%{"property" => "destination", "value" => dock}, state)
       when is_binary(dock) do
    if dock == state.destination do
      state
    else
      %{state | destination: dock, mode: :driving}
    end
  end

  defp apply_command(%{"property" => "hour", "value" => hour}, state) when is_integer(hour) do
    %{state | hour: hour}
  end

  defp apply_command(_, state), do: state

  defp snapshot(state) do
    {x, y} = state.position

    %{
      thing_id: state.thing_id,
      kind: :simulated,
      status: :online,
      battery: Float.round(state.battery, 1),
      position: %{x: Float.round(x * 1.0, 2), y: Float.round(y * 1.0, 2)},
      zone: Warehouse.zone_of(state.position),
      destination: state.destination,
      mode: state.mode,
      hour: state.hour
    }
  end

  defp schedule(tick_ms), do: Process.send_after(self(), :tick, tick_ms)
  defp clamp(value, minimum, maximum), do: min(max(value, minimum), maximum)
end
