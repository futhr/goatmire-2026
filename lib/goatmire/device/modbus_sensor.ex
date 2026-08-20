defmodule Goatmire.Device.ModbusSensor do
  @moduledoc """
  A 4–20 mA sensor on a current loop, read over Modbus TCP.

  ## Live zero

  The scale starts at 4 mA, not 0. The gap below is the channel the instrument
  uses to say it cannot measure:

      0 mA ─────── 3.6 ─── 3.8 ──────────── 20.5 ─── 21.0 ─────── 24 mA
      └─ wire break ─┘     └─ measurement ──┘        └─ short / fault ─┘

  Thresholds follow **NAMUR NE 43**: 3.8–20.5 mA is the valid range, ≤ 3.6 mA a
  low failure signal, ≥ 21.0 mA a high one.

  A faulted loop publishes a status, never a value. Scaling 3 mA into
  engineering units produces a confident negative number; a dashboard showing
  `0.0 bar` for a severed cable is what the live zero exists to prevent.

      Goatmire.Fleet.attach_modbus_sensor("tank-1",
        host: "192.168.8.20", register: 0,
        raw_min: 0, raw_max: 4095, ma_min: 0.0, ma_max: 20.0,
        unit: "bar", range_min: 0.0, range_max: 10.0)
  """

  use GenServer, restart: :transient

  require Logger

  alias Goatmire.Protocol.Modbus
  alias Goatmire.Transport

  # NAMUR NE 43
  @ne43_low_failure 3.6
  @ne43_low_valid 3.8
  @ne43_high_valid 20.5
  @ne43_high_failure 21.0

  @default_poll_ms 1_000

  @type status :: :ok | :under_range | :over_range | :wire_break | :short_circuit | :unreachable

  @doc "Builds the transient child specification keyed by sensor Thing ID."
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

  @doc "Starts one named Modbus sensor poller."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    thing_id = Keyword.fetch!(opts, :thing_id)
    GenServer.start_link(__MODULE__, opts, name: via(thing_id))
  end

  defp via(thing_id) do
    {:via, Registry, {Goatmire.Fleet.registry(), thing_id, %{kind: :modbus_sensor}}}
  end

  @impl true
  def init(opts) do
    state = %{
      thing_id: Keyword.fetch!(opts, :thing_id),
      host: Keyword.fetch!(opts, :host),
      port: Keyword.get(opts, :port, 502),
      unit_id: Keyword.get(opts, :unit_id, 1),
      register: Keyword.get(opts, :register, 0),
      scaling: Keyword.take(opts, [:raw_min, :raw_max, :ma_min, :ma_max]),
      unit: Keyword.get(opts, :unit, "unit"),
      range_min: Keyword.get(opts, :range_min, 0.0),
      range_max: Keyword.get(opts, :range_max, 100.0),
      poll_ms: Keyword.get(opts, :poll_ms, @default_poll_ms),
      socket: nil,
      last: nil,
      status: :unreachable
    }

    if state.poll_ms > 0, do: send(self(), :poll)
    {:ok, state}
  end

  @impl true
  def handle_call(:snapshot, _, state), do: {:reply, snapshot(state), state}

  @impl true
  def handle_info(:poll, state) do
    state =
      state
      |> ensure_connected()
      |> read_once()

    if state.poll_ms > 0, do: Process.send_after(self(), :poll, state.poll_ms)
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_, %{socket: socket}) when socket != nil, do: Modbus.close(socket)
  def terminate(_, _), do: :ok

  defp ensure_connected(%{socket: nil} = state) do
    case Modbus.connect(state.host, port: state.port) do
      {:ok, socket} ->
        %{state | socket: socket}

      {:error, reason} ->
        # A sensor whose gateway is unreachable is not a sensor reading zero.
        publish_fault(state, :unreachable, reason)
        %{state | socket: nil, status: :unreachable}
    end
  end

  defp ensure_connected(state), do: state

  defp read_once(%{socket: nil} = state), do: state

  defp read_once(state) do
    case Modbus.read_input_registers(state.socket, state.register, 1, unit_id: state.unit_id) do
      {:ok, [raw]} ->
        interpret(state, raw)

      {:error, reason} ->
        Logger.warning("modbus_sensor #{state.thing_id}: read failed — #{inspect(reason)}")
        if state.socket, do: Modbus.close(state.socket)
        publish_fault(state, :unreachable, reason)
        %{state | socket: nil, status: :unreachable}
    end
  end

  @doc """
  Classifies a loop current against NAMUR NE 43.
  """
  @spec classify(float()) :: status()
  def classify(ma) when ma <= @ne43_low_failure, do: :wire_break
  def classify(ma) when ma < @ne43_low_valid, do: :under_range
  def classify(ma) when ma >= @ne43_high_failure, do: :short_circuit
  def classify(ma) when ma > @ne43_high_valid, do: :over_range
  def classify(_), do: :ok

  @doc """
  Scales a valid loop current to engineering units: 4 mA is the bottom of the
  range, 20 mA the top. Raw counts are scaled first by
  `Goatmire.Protocol.Modbus.to_milliamps/2`.
  """
  @spec to_engineering(float(), number(), number()) :: float()
  def to_engineering(ma, range_min, range_max) do
    fraction = (ma - 4.0) / 16.0
    range_min + fraction * (range_max - range_min)
  end

  defp interpret(state, raw) do
    ma = Modbus.to_milliamps(raw, state.scaling)

    case classify(ma) do
      :ok ->
        value = to_engineering(ma, state.range_min, state.range_max)
        Transport.publish_telemetry(state.thing_id, "value", Float.round(value, 3))
        Transport.publish_telemetry(state.thing_id, "loop_ma", Float.round(ma, 2))
        Transport.publish_telemetry(state.thing_id, "status", "ok")
        emit(state, :ok, ma)
        %{state | last: value, status: :ok}

      fault ->
        # No `value` publish: the loop is saying it cannot measure.
        publish_fault(state, fault, ma)
        %{state | status: fault}
    end
  end

  defp publish_fault(state, fault, detail) do
    Transport.publish_telemetry(state.thing_id, "status", to_string(fault))

    if is_float(detail) do
      Transport.publish_telemetry(state.thing_id, "loop_ma", Float.round(detail, 2))
    end

    emit(state, fault, detail)
  end

  defp emit(state, status, detail) do
    :telemetry.execute(
      [:goatmire, :sensor, :reading],
      %{count: 1},
      %{thing_id: state.thing_id, status: status, detail: detail}
    )
  end

  defp snapshot(state) do
    %{
      thing_id: state.thing_id,
      kind: :modbus_sensor,
      status: if(state.status == :ok, do: :online, else: state.status),
      value: state.last,
      unit: state.unit,
      battery: nil,
      zone: nil,
      mode: nil,
      destination: nil
    }
  end
end
