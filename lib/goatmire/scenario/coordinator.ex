defmodule Goatmire.Scenario.Coordinator do
  @moduledoc "Owns one fleet mutation or scenario across all connected clients."

  alias Goatmire.Scenario.Storm

  use GenServer

  @doc "Starts the scenario coordinator."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Runs exclusively, or returns busy before any fleet mutation occurs."
  @spec exclusive((-> term())) :: term()
  def exclusive(fun), do: GenServer.call(__MODULE__, {:run, fun}, :infinity)

  @doc "Returns shared run status and the last completed result."
  @spec status() :: map()
  def status, do: GenServer.call(__MODULE__, :status)

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, %{task: nil, from: nil, caller_monitor: nil, last: nil}}
  end

  @impl true
  def handle_call(:status, _, state),
    do: {:reply, %{running: state.task != nil, last: state.last}, state}

  # This linked task must die with its owner; normal stops explicitly cancel it.
  def handle_call({:run, fun}, from, %{task: nil} = state) do
    # credo:disable-for-next-line OeditusCredo.Check.Warning.UnmanagedTask
    task = Task.async(fn -> Goatmire.Deadline.run(fun, 650_000) end)
    {:noreply, %{state | task: task, from: from, caller_monitor: Process.monitor(elem(from, 0))}}
  end

  def handle_call({:run, _}, _, state), do: {:reply, {:error, :busy}, state}

  @impl true
  def terminate(_, state) do
    if state.task, do: Task.shutdown(state.task, :brutal_kill)
    :ok
  end

  @impl true
  def handle_info({ref, {:ok, result}}, %{task: %{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    Process.demonitor(state.caller_monitor, [:flush])
    GenServer.reply(state.from, result)
    {:noreply, %{state | task: nil, from: nil, last: result}}
  end

  def handle_info({ref, {:error, reason}}, %{task: %{ref: ref}} = state),
    do: failed(state, reason)

  def handle_info({:DOWN, ref, :process, _, reason}, %{task: %{ref: ref}} = state),
    do: failed(state, reason)

  def handle_info(
        {:DOWN, ref, :process, _, _},
        %{caller_monitor: ref, task: %Task{} = task} = state
      ) do
    Task.shutdown(task, :brutal_kill)
    failed(state, :caller_down)
  end

  def handle_info(_, state), do: {:noreply, state}

  defp failed(state, reason) do
    Process.demonitor(state.caller_monitor, [:flush])
    GenServer.reply(state.from, {:error, reason})

    Phoenix.PubSub.broadcast(
      Goatmire.PubSub,
      Storm.topic(),
      {:storm_failed, "Scenario stopped. Reset and retry."}
    )

    {:noreply, %{state | task: nil, from: nil}}
  end
end
