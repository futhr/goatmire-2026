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
    case decode_event(%{thing_id: thing_id, property: property, value: value}) do
      {:ok, event} ->
        impl().publish(telemetry_topic(thing_id), %{
          "thing_id" => thing_id,
          "property" => property,
          "value" => event.value,
          "ts" => System.system_time(:millisecond)
        })

      :error ->
        {:error, :invalid_telemetry}
    end
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
  Mixed aliases for one envelope field are rejected. Nested atom keys become
  strings, matching MQTT JSON; colliding keys are rejected. Existing limits
  (four levels, 32 entries per collection, 1,024 encoded bytes) apply before
  publishing, with structure checked before encoding.
  """
  @spec decode_event(map()) :: {:ok, map()} | :error
  def decode_event(payload) when is_map(payload) do
    if Enum.any?(
         [:thing_id, :property, :value],
         &(Map.has_key?(payload, &1) and Map.has_key?(payload, Atom.to_string(&1)))
       ) do
      :error
    else
      decode_fields(payload)
    end
  end

  def decode_event(_), do: :error

  defp decode_fields(%{"thing_id" => thing_id, "property" => property, "value" => value}),
    do: decode_fields(%{thing_id: thing_id, property: property, value: value})

  defp decode_fields(%{thing_id: thing_id, property: property, value: value}) do
    with true <- valid_identifier?(thing_id) and valid_identifier?(property),
         true <- bounded_json?(value, 4),
         {:ok, value} <- Goatmire.JSON.normalize(value),
         true <- valid_value?(value) do
      {:ok, %{thing_id: thing_id, property: property, value: value}}
    else
      _ -> :error
    end
  end

  defp decode_fields(_), do: :error

  @doc "Validates a payload and binds its identity to the telemetry topic."
  @spec decode_event(term(), String.t()) :: {:ok, map()} | :error
  def decode_event(payload, topic) do
    with {:ok, event} <- decode_event(payload),
         true <- topic == telemetry_topic(event.thing_id) do
      {:ok, event}
    else
      _ -> :error
    end
  end

  @doc "Checks an identifier used by native telemetry or a translated device topic."
  @spec valid_identifier?(term()) :: boolean()
  def valid_identifier?(value) when is_binary(value) and byte_size(value) in 1..128,
    do: String.valid?(value) and Regex.match?(~r/\A[a-zA-Z0-9_.:-]+\z/, value)

  def valid_identifier?(_), do: false

  defp valid_value?(value) when is_binary(value),
    do: byte_size(value) <= 1024 and String.valid?(value)

  defp valid_value?(value) when is_map(value) or is_list(value) do
    case Jason.encode(value) do
      {:ok, json} -> byte_size(json) <= 1024
      _ -> false
    end
  end

  defp valid_value?(value), do: is_number(value) or is_boolean(value) or is_nil(value)

  defp bounded_json?(_, 0), do: false
  defp bounded_json?(%_{}, _), do: false

  defp bounded_json?(map, depth) when is_map(map),
    do:
      map_size(map) <= 32 and
        Enum.all?(map, fn {key, value} ->
          (is_binary(key) or is_atom(key)) and bounded_json?(value, depth - 1)
        end)

  defp bounded_json?(list, depth) when is_list(list),
    do: bounded_list?(list, depth, 32)

  defp bounded_json?(value, _), do: valid_value?(value)

  defp bounded_list?([], _, _), do: true

  defp bounded_list?([head | tail], depth, remaining) when remaining > 0,
    do: bounded_json?(head, depth - 1) and bounded_list?(tail, depth, remaining - 1)

  defp bounded_list?(_, _, _), do: false
end
