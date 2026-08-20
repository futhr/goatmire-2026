defmodule Goatmire.Device.Real do
  @moduledoc """
  A physical device, declared to this node.

  The device needs nothing from us — it publishes on
  `goatmire/things/<thing_id>/telemetry` and that is the contract. This process
  exists for liveness (a device that stops publishing becomes visibly `:stale`
  rather than vanishing) and presence (a declared device appears from boot,
  before its first reading).

  Readings reach the engine directly off the transport; this observes rather
  than relays, so it is never in the data path.

      config :goatmire, real_devices: [[thing_id: "agv-01", stale_after_ms: 15_000]]
  """

  use GenServer, restart: :transient

  alias Goatmire.Transport
  alias Goatmire.Transport.Local

  @default_stale_after_ms 15_000
  @check_interval_ms 2_000

  @doc "Builds the transient child specification keyed by physical Thing ID."
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

  @doc "Starts liveness tracking for one declared physical Thing."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    thing_id = Keyword.fetch!(opts, :thing_id)
    GenServer.start_link(__MODULE__, opts, name: via(thing_id))
  end

  defp via(thing_id) do
    {:via, Registry, {Goatmire.Fleet.registry(), thing_id, %{kind: :real}}}
  end

  @impl true
  def init(opts) do
    thing_id = Keyword.fetch!(opts, :thing_id)
    :ok = Transport.impl().subscribe(Transport.telemetry_topic(thing_id))

    Process.send_after(self(), :check_liveness, @check_interval_ms)

    {:ok,
     %{
       thing_id: thing_id,
       stale_after_ms: Keyword.get(opts, :stale_after_ms, @default_stale_after_ms),
       last_seen_at: nil,
       properties: %{},
       status: :never_seen
     }}
  end

  @impl true
  def handle_call(:snapshot, _, state), do: {:reply, snapshot(state), state}

  @impl true
  def handle_info({:goatmire_publish, _, _} = message, state) do
    case Local.accept(message) do
      {:ok, _, payload} -> {:noreply, observe(payload, state)}
      :ignore -> {:noreply, state}
    end
  end

  def handle_info(:check_liveness, state) do
    Process.send_after(self(), :check_liveness, @check_interval_ms)
    {:noreply, %{state | status: liveness(state)}}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp observe(payload, state) do
    case Transport.decode_event(payload) do
      {:ok, %{property: property, value: value}} ->
        %{
          state
          | properties: Map.put(state.properties, property, value),
            last_seen_at: System.monotonic_time(:millisecond),
            status: :online
        }

      :error ->
        state
    end
  end

  defp liveness(%{last_seen_at: nil}), do: :never_seen

  defp liveness(%{last_seen_at: last_seen_at, stale_after_ms: stale_after_ms}) do
    if System.monotonic_time(:millisecond) - last_seen_at > stale_after_ms do
      :stale
    else
      :online
    end
  end

  defp snapshot(state) do
    %{
      thing_id: state.thing_id,
      kind: :real,
      status: liveness(state),
      properties: state.properties,
      battery: Map.get(state.properties, "battery"),
      zone: Map.get(state.properties, "zone"),
      mode: Map.get(state.properties, "mode"),
      destination: Map.get(state.properties, "destination"),
      last_seen_ms_ago: age(state)
    }
  end

  defp age(%{last_seen_at: nil}), do: nil
  defp age(%{last_seen_at: at}), do: System.monotonic_time(:millisecond) - at
end
