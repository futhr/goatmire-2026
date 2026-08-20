defmodule Goatmire.Protocol.VDA5050.Bridge do
  @moduledoc """
  Translates VDA 5050 traffic into the engine's event vocabulary, and actuation
  back into orders. A real AGV speaking the standard becomes a participant the
  engine cannot distinguish from a simulated one.

  Preserves all three connection states rather than reducing them to a boolean.
  `CONNECTIONBROKEN` arrives either as the broker-published Last Will or from
  this bridge's own liveness deadline. Vehicles in that state are reported, not
  removed.
  """

  use GenServer

  require Logger

  alias Goatmire.Protocol.VDA5050
  alias Goatmire.Transport
  alias Goatmire.Transport.Local

  @pubsub Goatmire.PubSub
  @topic "goatmire:vda5050"

  # How long a silent vehicle stays ONLINE before the bridge calls it broken.
  # The standard leaves this to the integrator; a fleet controller picks it
  # from the vehicle's reporting interval and how far one can travel in that
  # time.
  @default_deadline_ms 5_000
  @sweep_ms 1_000

  @doc "Starts the VDA 5050 MQTT bridge."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "PubSub topic carrying vehicle connection-state transitions."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc "Connection state of every vehicle the bridge has seen."
  @spec vehicles() :: %{String.t() => VDA5050.connection_state()}
  def vehicles, do: GenServer.call(__MODULE__, :vehicles)

  @doc """
  Sends a destination to a vehicle as a VDA 5050 order.

  Called by whatever is actuating; the engine's own `set_prop` path stays on
  the native command topic, so a VDA 5050 vehicle and a native one are driven
  through their own vocabularies rather than a lowest common denominator.
  """
  @spec send_order(String.t(), String.t(), {number(), number()}) :: :ok | {:error, term()}
  def send_order(serial, node_id, position) do
    GenServer.call(__MODULE__, {:order, serial, node_id, position})
  end

  @impl true
  def init(opts) do
    :ok = Transport.impl().subscribe(VDA5050.state_filter())
    :ok = Transport.impl().subscribe(VDA5050.connection_filter())

    Process.send_after(self(), :sweep, @sweep_ms)

    {:ok,
     %{
       deadline_ms: Keyword.get(opts, :deadline_ms, @default_deadline_ms),
       vehicles: %{},
       header_ids: %{}
     }}
  end

  @impl true
  def handle_call(:vehicles, _, state) do
    {:reply, Map.new(state.vehicles, fn {serial, v} -> {serial, v.connection} end), state}
  end

  def handle_call({:order, serial, node_id, position}, _, state) do
    header_id = Map.get(state.header_ids, {serial, :order}, 0)
    payload = VDA5050.order(serial, node_id, position, header_id)
    result = Transport.impl().publish(VDA5050.topic(serial, :order), payload)

    {:reply, result,
     %{state | header_ids: Map.put(state.header_ids, {serial, :order}, header_id + 1)}}
  end

  @impl true
  def handle_info({:goatmire_publish, topic, payload} = message, state) do
    case Local.accept(message) do
      {:ok, _, _} -> {:noreply, route(topic, payload, state)}
      :ignore -> {:noreply, state}
    end
  end

  def handle_info(:sweep, state) do
    Process.send_after(self(), :sweep, @sweep_ms)
    {:noreply, sweep(state)}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp route(topic, payload, state) do
    cond do
      String.ends_with?(topic, "/state") -> handle_state(payload, state)
      String.ends_with?(topic, "/connection") -> handle_connection(payload, state)
      true -> state
    end
  end

  defp handle_state(payload, state) do
    case VDA5050.readings_from_state(payload) do
      {:ok, serial, readings} ->
        # Re-publish onto the engine's own telemetry topics. The engine has one
        # event shape; protocol dialects are translated at the edge, which is
        # the only place that scales past two protocols.
        Enum.each(readings, fn {property, value} ->
          Transport.publish_telemetry(serial, property, value)
        end)

        mark(state, serial, :online)

      :error ->
        state
    end
  end

  defp handle_connection(%{"serialNumber" => serial, "connectionState" => connection}, state) do
    mark(state, serial, decode_connection(connection))
  end

  defp handle_connection(_, state), do: state

  defp decode_connection("ONLINE"), do: :online
  defp decode_connection("OFFLINE"), do: :offline
  defp decode_connection("CONNECTIONBROKEN"), do: :connection_broken
  defp decode_connection(_), do: :connection_broken

  defp mark(state, serial, connection) do
    previous = get_in(state.vehicles, [serial, Access.key(:connection)])

    vehicle = %{connection: connection, last_seen_at: System.monotonic_time(:millisecond)}
    state = put_in(state.vehicles[serial], vehicle)

    if previous != connection do
      Logger.info("vda5050: #{serial} #{previous || "unknown"} → #{connection}")

      broadcast({:vda5050_connection, %{serial_number: serial, from: previous, to: connection}})

      :telemetry.execute(
        [:goatmire, :vda5050, :connection],
        %{count: 1},
        %{serial_number: serial, state: connection}
      )
    end

    state
  end

  # A vehicle that goes quiet without announcing OFFLINE is broken, not gone.
  # It stays in the map, visibly, in the third state.
  defp sweep(state) do
    now = System.monotonic_time(:millisecond)

    Enum.reduce(state.vehicles, state, fn {serial, vehicle}, acc ->
      overdue? = now - vehicle.last_seen_at > acc.deadline_ms

      if vehicle.connection == :online and overdue? do
        mark(acc, serial, :connection_broken)
      else
        acc
      end
    end)
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, message)
  catch
    :exit, _ -> :ok
  end
end
