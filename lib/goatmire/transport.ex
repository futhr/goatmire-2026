defmodule Goatmire.Transport do
  @moduledoc """
  The seam between the engine and whatever produces events.

  Implementations: `Goatmire.Transport.Local` (in-BEAM `Phoenix.PubSub`, the
  default) and `Goatmire.Transport.MQTT` (real broker). Select with
  `config :goatmire, transport: Goatmire.Transport.MQTT`.

  ## Topics

      goatmire/things/<thing_id>/telemetry   device → engine
      goatmire/things/<thing_id>/command     engine → device

  Alerts do not cross the transport; observers subscribe to
  `Goatmire.Engine.topic()` on `Goatmire.PubSub`.

  Telemetry payloads are JSON objects:

      {"thing_id":"agv-42","property":"battery","value":18,"ts":1234567890}

  A device publishing that shape on that topic is a first-class participant;
  there is no separate code path for real hardware.
  """

  @type topic :: String.t()
  @type payload :: map()

  @doc "Starts the transport under the application supervisor."
  @callback child_spec(keyword()) :: Supervisor.child_spec()

  @doc "Publishes a payload to a topic."
  @callback publish(topic(), payload()) :: :ok | {:error, term()}

  @doc "Subscribes the calling process to a topic. Wildcards use MQTT syntax (`+`, `#`)."
  @callback subscribe(topic()) :: :ok | {:error, term()}

  @telemetry_topic "goatmire/things/+/telemetry"

  @doc "The configured transport module."
  @spec impl() :: module()
  def impl, do: Application.get_env(:goatmire, :transport, Goatmire.Transport.Local)

  @doc "Publishes a device telemetry reading."
  @spec publish_telemetry(String.t(), String.t(), term()) :: :ok | {:error, term()}
  def publish_telemetry(thing_id, property, value) do
    impl().publish(telemetry_topic(thing_id), %{
      "thing_id" => thing_id,
      "property" => property,
      "value" => value,
      "ts" => System.system_time(:millisecond)
    })
  end

  @doc "Publishes an actuation command to a device."
  @spec publish_command(String.t(), String.t(), term()) :: :ok | {:error, term()}
  def publish_command(thing_id, property, value) do
    impl().publish("goatmire/things/#{thing_id}/command", %{
      "thing_id" => thing_id,
      "property" => property,
      "value" => value,
      "ts" => System.system_time(:millisecond)
    })
  end

  @doc "Subscribes the caller to every device's telemetry."
  @spec subscribe_all_telemetry() :: :ok | {:error, term()}
  def subscribe_all_telemetry, do: impl().subscribe(@telemetry_topic)

  @doc "Subscribes the caller to one device's command stream."
  @spec subscribe_commands(String.t()) :: :ok | {:error, term()}
  def subscribe_commands(thing_id), do: impl().subscribe("goatmire/things/#{thing_id}/command")

  @doc "Topic a device publishes its readings on."
  @spec telemetry_topic(String.t()) :: String.t()
  def telemetry_topic(thing_id), do: "goatmire/things/#{thing_id}/telemetry"

  @doc """
  Normalises an inbound payload into the engine's event shape.

  Accepts both the JSON map a broker delivers and the atom-keyed map a local
  publisher sends, so the engine has exactly one event type to handle.
  """
  @spec decode_event(map()) :: {:ok, map()} | :error
  def decode_event(%{"thing_id" => thing_id, "property" => property, "value" => value}) do
    {:ok, %{thing_id: thing_id, property: property, value: value}}
  end

  def decode_event(%{thing_id: thing_id, property: property, value: value}) do
    {:ok, %{thing_id: thing_id, property: property, value: value}}
  end

  def decode_event(_), do: :error
end
