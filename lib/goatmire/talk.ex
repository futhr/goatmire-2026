defmodule Goatmire.Talk do
  @moduledoc """
  Play-step broadcast for the presenter.

  One scripted step per press: the presenter broadcasts, the target pane's
  LiveView performs the same handler a click would have, visibly. Steps go
  through PubSub so a pane crash never touches the presenter process.
  """

  @play_topic "talk:play"

  @doc "PubSub topic carrying `{:talk_play, pane, step}` messages."
  @spec play_topic() :: String.t()
  def play_topic, do: @play_topic

  @doc "Broadcasts one scripted step to a demo pane."
  @spec play(atom(), atom()) :: :ok
  def play(pane, step) do
    Phoenix.PubSub.broadcast(Goatmire.PubSub, @play_topic, {:talk_play, pane, step})
  end
end
