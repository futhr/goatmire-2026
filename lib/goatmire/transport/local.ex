defmodule Goatmire.Transport.Local do
  @moduledoc """
  In-BEAM transport over `Phoenix.PubSub`. The default — no broker, no
  configuration.

  MQTT topic filters are honoured, so wildcard semantics (`+`, `#`) match the
  broker implementation. An exact filter subscribes to that one topic, so a
  device receives only the messages addressed to it. A wildcard filter
  subscribes to a fan-out topic and filters on delivery; a process holding any
  wildcard listens on the fan-out alone, so no message arrives twice.

  Messages arrive as `{:goatmire_publish, topic, payload}`; subscribers pass
  them through `accept/1`.
  """

  @behaviour Goatmire.Transport

  @pubsub Goatmire.PubSub
  @fanout "goatmire:transport"
  @exact_prefix "goatmire:transport:"

  @impl Goatmire.Transport
  def child_spec(_) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}, type: :worker, restart: :temporary}
  end

  @doc false
  @spec start_link() :: :ignore
  def start_link, do: :ignore

  @impl Goatmire.Transport
  def publish(topic, payload) do
    message = {:goatmire_publish, topic, payload}

    with :ok <- Phoenix.PubSub.broadcast(@pubsub, @fanout, message) do
      Phoenix.PubSub.broadcast(@pubsub, exact_topic(topic), message)
    end
  end

  @impl Goatmire.Transport
  def subscribe(filter) do
    filters = Process.get(__MODULE__, MapSet.new())

    with :ok <- register(filter, filters) do
      Process.put(__MODULE__, MapSet.put(filters, filter))
      :ok
    end
  end

  # One listening point per process: the fan-out serves every wildcard holder,
  # and an exact-only subscriber never sees another device's traffic.
  defp register(filter, filters) do
    cond do
      MapSet.member?(filters, filter) -> :ok
      Enum.any?(filters, &wildcard?/1) -> :ok
      wildcard?(filter) -> subscribe_fanout(filters)
      true -> Phoenix.PubSub.subscribe(@pubsub, exact_topic(filter))
    end
  end

  defp subscribe_fanout(filters) do
    with :ok <- Phoenix.PubSub.subscribe(@pubsub, @fanout) do
      Enum.each(filters, &Phoenix.PubSub.unsubscribe(@pubsub, exact_topic(&1)))
    end
  end

  defp wildcard?(filter), do: Enum.any?(String.split(filter, "/"), &(&1 in ["+", "#"]))

  defp exact_topic(topic), do: @exact_prefix <> topic

  @doc """
  Whether a published topic matches a subscribed filter, using MQTT wildcard
  semantics. Exposed so `Goatmire.Transport.MQTT` can reuse it for the local
  bridge and so the behaviour is directly testable.
  """
  @spec topic_match?(String.t(), String.t()) :: boolean()
  def topic_match?(topic, filter) do
    not (String.starts_with?(topic, "$SYS") and not String.starts_with?(filter, "$SYS")) and
      match_levels(String.split(topic, "/"), String.split(filter, "/"))
  end

  defp match_levels(_, ["#"]), do: true
  defp match_levels(_, ["#" | _]), do: false
  defp match_levels([], []), do: true
  defp match_levels([], _), do: false
  defp match_levels(_, []), do: false
  defp match_levels([_ | topic], ["+" | filter]), do: match_levels(topic, filter)
  defp match_levels([same | topic], [same | filter]), do: match_levels(topic, filter)
  defp match_levels(_, _), do: false

  @doc """
  Filters an incoming message against this process's subscriptions.

  A subscriber's `handle_info` calls this rather than matching the topic
  itself; it returns `{:ok, topic, payload}` only for topics the process
  actually subscribed to.
  """
  @spec accept({:goatmire_publish, String.t(), map()}) :: {:ok, String.t(), map()} | :ignore
  def accept({:goatmire_publish, topic, payload}) do
    subscribed? =
      __MODULE__
      |> Process.get(MapSet.new())
      |> Enum.any?(&topic_match?(topic, &1))

    if subscribed?, do: {:ok, topic, payload}, else: :ignore
  end

  def accept(_), do: :ignore
end
