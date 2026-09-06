defmodule Goatmire.Talk do
  @moduledoc """
  Shared action dispatch for the presenter.

  The server command owner executes each scripted step once and broadcasts
  its resulting pane state. Connected views render the shared result.
  """
  alias Goatmire.Talk.{Actions, Clock}

  @play_topic "talk:play"

  @doc "PubSub topic carrying shared pane results and action failures."
  @spec play_topic() :: String.t()
  def play_topic, do: @play_topic

  @doc "Broadcasts one scripted step to a demo pane."
  @spec play(atom(), atom()) :: :ok
  def play(:presenter, :run_code),
    do:
      Actions.enqueue([
        {nil, nil, :presenter, {:run_code, Clock.snapshot().slide}}
      ])

  def play(pane, step) do
    Actions.enqueue([{nil, nil, pane, step}])
  end
end
