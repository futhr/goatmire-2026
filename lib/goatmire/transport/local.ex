defmodule Goatmire.Transport.Local do
  @moduledoc """
  In-BEAM transport over `Phoenix.PubSub`. The default — no broker, no
  configuration.

  MQTT topic filters are honoured by subscribing to a fan-out topic and
  filtering on delivery, so wildcard semantics (`+`, `#`) match the broker
  implementation. Messages arrive as `{:goatmire_publish, topic, payload}`;
  subscribers pass them through `accept/1`.
  """

  @behaviour Goatmire.Transport

  @pubsub Goatmire.PubSub
  @fanout "goatmire:transport"

  @impl Goatmire.Transport
  def child_spec(_) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}, type: :worker, restart: :temporary}
  end

  @doc false
  @spec start_link() :: :ignore
  def start_link, do: :ignore

  @impl Goatmire.Transport
  def publish(topic, payload) do
    Phoenix.PubSub.broadcast(@pubsub, @fanout, {:goatmire_publish, topic, payload})
  end

  @impl Goatmire.Transport
  def subscribe(filter) do
    with :ok <- Phoenix.PubSub.subscribe(@pubsub, @fanout) do
      filters = Process.get(__MODULE__, MapSet.new())
      Process.put(__MODULE__, MapSet.put(filters, filter))
      :ok
    end
  end

  @doc """
  Whether a published topic matches a subscribed filter, using MQTT wildcard
  semantics. Exposed so `Goatmire.Transport.MQTT` can reuse it for the local
  bridge and so the behaviour is directly testable.
  """
  @spec topic_match?(String.t(), String.t()) :: boolean()
  def topic_match?(topic, filter) do
    match_levels(String.split(topic, "/"), String.split(filter, "/"))
  end

  defp match_levels(_, ["#" | _]), do: true
  defp match_levels([], []), do: true
  defp match_levels([], _), do: false
  defp match_levels(_, []), do: false
  defp match_levels([_ | topic], ["+" | filter]), do: match_levels(topic, filter)
  defp match_levels([same | topic], [same | filter]), do: match_levels(topic, filter)
  defp match_levels(_, _), do: false

  @doc """
  Filters an incoming fan-out message against this process's subscriptions.

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
