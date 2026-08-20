defmodule Goatmire.Transport.MQTT do
  @moduledoc """
  MQTT 3.1.1 transport against a real broker, used by the Docker swarm and any
  physical device.

  Holds one broker session per node and re-broadcasts inbound messages onto the
  same local fan-out `Goatmire.Transport.Local` uses, so a subscriber's mailbox
  is identical whichever transport is configured.

      config :goatmire,
        transport: Goatmire.Transport.MQTT,
        mqtt: [host: "localhost", port: 1883, client_id: "goatmire-engine"]

  A physical device joins by publishing on
  `goatmire/things/<thing_id>/telemetry` and subscribing to
  `goatmire/things/<thing_id>/command`. No SDK, no registration call.
  """

  @behaviour Goatmire.Transport
  @connection_timeout 15_000

  require Logger

  alias Goatmire.Transport.Local

  @impl Goatmire.Transport
  def child_spec(_) do
    config = config()

    %{
      id: __MODULE__,
      start:
        {Tortoise311.Connection, :start_link,
         [
           [
             client_id: config[:client_id],
             server: {Tortoise311.Transport.Tcp, host: config[:host], port: config[:port]},
             handler: {__MODULE__.Handler, []},
             user_name: config[:username],
             password: config[:password],
             will: nil
           ]
         ]},
      type: :supervisor,
      restart: :permanent
    }
  end

  @impl Goatmire.Transport
  def publish(topic, payload) do
    Tortoise311.publish(config()[:client_id], topic, Jason.encode!(payload), qos: 0)
  end

  @impl Goatmire.Transport
  def subscribe(filter) do
    # Register the local filter first so a message that arrives between the
    # broker SUBSCRIBE and the local registration is not dropped by `accept/1`.
    :ok = Local.subscribe(filter)

    client_id = config()[:client_id]

    # Tortoise connects asynchronously. Without this barrier, a consumer that
    # subscribes during application boot can enqueue SUBSCRIBE ahead of the
    # connection process's own :connect message. Its inflight tracker then
    # waits on the very process it is blocking, and the subscription times out.
    with {:ok, _} <-
           Tortoise311.Connection.connection(client_id, timeout: @connection_timeout),
         {:ok, _} <- Tortoise311.Connection.subscribe(client_id, [{filter, 0}]) do
      :ok
    end
  end

  @doc "Resolved MQTT settings, with defaults applied."
  @spec config() :: keyword()
  def config do
    defaults = [
      host: "localhost",
      port: 1883,
      client_id: "goatmire-#{node()}",
      username: nil,
      password: nil
    ]

    Keyword.merge(defaults, Application.get_env(:goatmire, :mqtt, []))
  end

  defmodule Handler do
    @moduledoc """
    Bridges broker deliveries onto the local fan-out.

    Decoding failures are logged and dropped rather than crashing the session:
    a malformed payload from one device on a shared broker must not take the
    engine's connection down.
    """

    use Tortoise311.Handler

    require Logger

    @pubsub Goatmire.PubSub
    @fanout "goatmire:transport"

    @impl true
    def init(_), do: {:ok, %{}}

    @impl true
    def connection(status, state) do
      Logger.info("mqtt: connection #{inspect(status)}")
      {:ok, state}
    end

    @impl true
    def handle_message(topic_levels, payload, state) do
      topic = Enum.join(topic_levels, "/")

      case Jason.decode(payload) do
        {:ok, decoded} ->
          Phoenix.PubSub.broadcast(@pubsub, @fanout, {:goatmire_publish, topic, decoded})

        {:error, reason} ->
          Logger.warning("mqtt: undecodable payload on #{topic} — #{inspect(reason)}")
      end

      {:ok, state}
    end

    @impl true
    def subscription(_, _, state), do: {:ok, state}

    @impl true
    def terminate(reason, _) do
      Logger.info("mqtt: session terminated — #{inspect(reason)}")
      :ok
    end
  end
end
