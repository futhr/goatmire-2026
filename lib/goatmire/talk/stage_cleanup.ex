defmodule Goatmire.Talk.StageCleanup do
  @moduledoc """
  Clears the warehouse when the talk leaves the storm slides, in either
  direction.

  A storm keeps its fleet running so the enforce run can reuse it, and a slide
  change never touches the fleet. Without this, sixty robots would keep
  reporting through the rest of the talk. Leaving the storm range runs the
  same clear as the pane's Clear button; a storm still in flight is waited
  out rather than interrupted.
  """

  use GenServer

  alias Goatmire.Scenario.{Coordinator, Storm}
  alias Goatmire.Talk.Clock

  @storm_slides 17..18
  @retry_ms 1_000

  @doc "Starts the watcher; pass `name: nil` for an unregistered instance."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "Whether moving between two slides leaves the storm range."
  @spec leaving?(pos_integer() | nil, pos_integer()) :: boolean()
  def leaving?(from, to), do: from in @storm_slides and to not in @storm_slides

  @impl true
  def init(opts) do
    if Keyword.get(opts, :subscribe, true),
      do: Phoenix.PubSub.subscribe(Goatmire.PubSub, Clock.topic())

    {:ok, %{slide: nil}}
  end

  @impl true
  def handle_info({:talk_clock, %{slide: slide}}, state) do
    if leaving?(state.slide, slide), do: send(self(), :clear)
    {:noreply, %{state | slide: slide}}
  end

  # Returning to the storm slides before the clear lands cancels it.
  def handle_info(:clear, %{slide: slide} = state) when slide in @storm_slides,
    do: {:noreply, state}

  def handle_info(:clear, state) do
    case Coordinator.exclusive(&Storm.clear/0) do
      {:error, :busy} -> Process.send_after(self(), :clear, @retry_ms)
      _ -> :ok
    end

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}
end
