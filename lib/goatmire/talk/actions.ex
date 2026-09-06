defmodule Goatmire.Talk.Actions do
  @moduledoc "Executes shared presenter commands in order and acknowledges completed steps."
  use GenServer
  alias Goatmire.{Engine, Gate, Notebook, Rules, Talk}
  alias Goatmire.Talk.{Clock, Store}

  @doc "Starts the shared command owner."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Queues commands as {slide, index, pane, action}; nil slide denotes a manual command."
  @spec enqueue([tuple()]) :: :ok | {:error, :busy}
  def enqueue(jobs), do: GenServer.call(__MODULE__, {:enqueue, jobs})

  @doc "Returns shared pane state, including notebook bindings after a browser refresh."
  @spec get(atom()) :: map()
  def get(pane), do: GenServer.call(__MODULE__, {:get, pane})

  @doc "Cancels unfinished commands and clears shared demo state."
  @spec reset() :: :ok
  def reset, do: GenServer.cast(__MODULE__, :reset)

  @doc "Cancels notebook evaluation and clears its queued steps before resetting bindings."
  @spec reset_notebook() :: :ok
  def reset_notebook, do: GenServer.call(__MODULE__, :reset_notebook)

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)
    if Process.whereis(Clock), do: send(Clock, :play_reset_pending)
    {:ok, %{panes: Store.get_data(:panes) || %{}, jobs: [], task: nil, current: nil}}
  end

  @impl true
  def handle_call(:reset_notebook, _, state) do
    state =
      case state.current do
        {_, _, :notebook, _} ->
          Task.shutdown(state.task, :brutal_kill)
          %{state | task: nil, current: nil}

        _ ->
          state
      end

    pane = notebook(get_in(state.panes, [:notebook, :slug]) || "05_agent_policy_proof")
    panes = Map.put(state.panes, :notebook, pane)
    Store.put_data(:panes, panes)
    Phoenix.PubSub.broadcast(Goatmire.PubSub, Talk.play_topic(), {:talk_state, :notebook, pane})
    send(Clock, {:play_clear_slide, 17})
    jobs = Enum.reject(state.jobs, fn {_, _, target, _} -> target == :notebook end)
    {:reply, :ok, advance(%{state | panes: panes, jobs: jobs})}
  end

  def handle_call({:get, pane}, _, state), do: {:reply, Map.get(state.panes, pane, %{}), state}

  def handle_call({:enqueue, jobs}, _, state) do
    if length(state.jobs) + length(jobs) > 32 do
      {:reply, {:error, :busy}, state}
    else
      {:reply, :ok, advance(%{state | jobs: state.jobs ++ jobs})}
    end
  end

  @impl true
  def handle_cast(:reset, state) do
    if state.task, do: Task.shutdown(state.task, :brutal_kill)
    Store.put_data(:panes, %{})
    Phoenix.PubSub.broadcast(Goatmire.PubSub, Talk.play_topic(), :talk_reset)
    {:noreply, %{state | panes: %{}, jobs: [], task: nil, current: nil}}
  end

  @impl true
  def handle_info({ref, {:ok, {:ok, pane_state}}}, %{task: %{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    {slide, index, pane, _} = state.current
    panes = Map.put(state.panes, pane, pane_state)
    Store.put_data(:panes, panes)
    Phoenix.PubSub.broadcast(Goatmire.PubSub, Talk.play_topic(), {:talk_state, pane, pane_state})
    if slide, do: send(Clock, {:play_completed, slide, index})
    {:noreply, advance(%{state | panes: panes, task: nil, current: nil})}
  end

  def handle_info({ref, result}, %{task: %{ref: ref}} = state), do: failed(state, result)

  def handle_info({:DOWN, ref, :process, _, reason}, %{task: %{ref: ref}} = state),
    do: failed(state, reason)

  def handle_info(_, state), do: {:noreply, state}

  defp failed(state, reason) do
    {slide, index, pane, _} = state.current
    if slide, do: send(Clock, {:play_failed, slide, index})

    Phoenix.PubSub.broadcast(
      Goatmire.PubSub,
      Talk.play_topic(),
      {:talk_action_failed, pane, inspect(reason)}
    )

    jobs = Enum.reject(state.jobs, fn {queued_slide, _, _, _} -> queued_slide == slide end)
    {:noreply, advance(%{state | jobs: jobs, task: nil, current: nil})}
  end

  defp advance(%{task: nil, jobs: [{_, _, pane, action} = job | jobs]} = state) do
    panes = state.panes

    task =
      Task.async(fn -> Goatmire.Deadline.run(fn -> execute(pane, action, panes) end, 330_000) end)

    %{state | task: task, current: job, jobs: jobs}
  end

  defp advance(state), do: state

  defp execute(:presenter, {:run_code, slide}, panes) do
    with %{code: code} <- GoatmireWeb.Presenter.CodeExamples.example(slide),
         {:ok, {:ok, value, _, _, output}} <-
           Goatmire.Deadline.run(fn -> Notebook.eval(code, []) end, Notebook.eval_timeout()) do
      results = get_in(panes, [:presenter, :code_results]) || %{}

      {:ok,
       %{code_results: Map.put(results, slide, %{status: :ok, value: value, output: output})}}
    else
      other -> {:error, other}
    end
  end

  defp execute(:rules, :seed_deployed, _) do
    [rule, _] = Rules.research_state_conflict_pair()

    case Engine.deploy([rule], scenario: :rule_form_seed) do
      {:ok, %{withheld: []}} ->
        {:ok, %{params: params(rule), verdict: nil, submitted_rule: nil, deployed: false}}

      other ->
        {:error, other}
    end
  end

  defp execute(:rules, :load_example, _) do
    [_, rule] = Rules.research_state_conflict_pair()
    {:ok, %{params: params(rule), verdict: nil, submitted_rule: nil, deployed: false}}
  end

  defp execute(:rules, :check, _) do
    [_, rule] = Rules.research_state_conflict_pair()

    {:ok, verdict, _} =
      Gate.verify_partitioned(Engine.deployed_rules() ++ [rule], scenario: :rule_form)

    if verdict.status == :unverified,
      do: {:error, :unverified},
      else:
        {:ok, %{params: params(rule), verdict: verdict, submitted_rule: rule, deployed: false}}
  end

  defp execute(:warehouse, mode, _) when mode in [:observe, :enforce] do
    with {:ok, summary} <-
           Goatmire.Scenario.Storm.run(
             mode: mode,
             fleet_size: 60,
             duration_seconds: 30,
             keep_fleet: true
           ) do
      {:ok, %{storm: summary}}
    end
  end

  defp execute(:warehouse, :clear, _) do
    case Goatmire.Scenario.Coordinator.exclusive(&Goatmire.Fleet.stop_all/0) do
      {:error, _} = error -> error
      _ -> {:ok, %{}}
    end
  end

  defp execute(:diagnostics, :diagnose, _) do
    with {:ok, result} <-
           Goatmire.Diagnostics.Analysis.run(
             "Explain the recorded alerts and verdict. Cite the supplied fields."
           ) do
      {:ok, %{result: {:ok, result}}}
    end
  end

  defp execute(:verify, :run_policy, _), do: {:ok, %{policy: Goatmire.VerificationDemo.run()}}

  defp execute(:notebook, {:open, slug}, _) do
    if slug in Notebook.list(), do: {:ok, notebook(slug)}, else: {:error, :unknown_notebook}
  end

  defp execute(:notebook, :reset, panes),
    do: {:ok, notebook(get_in(panes, [:notebook, :slug]) || "05_agent_policy_proof")}

  defp execute(:notebook, action, panes) do
    notebook = Map.get_lazy(panes, :notebook, fn -> notebook("05_agent_policy_proof") end)

    cell =
      case action do
        :run_next ->
          Enum.find(
            notebook.cells,
            &(&1.type == :code and get_in(notebook.results, [&1.index, :status]) != :ok)
          )

        {:run, index} ->
          Enum.find(notebook.cells, &(&1.type == :code and &1.index == index))

        _ ->
          nil
      end

    if cell, do: evaluate_cell(notebook, cell), else: {:error, :no_cell}
  end

  defp execute(_, _, _), do: {:error, :unsupported_action}

  defp evaluate_cell(notebook, cell) do
    started = System.monotonic_time(:millisecond)

    case Goatmire.Deadline.run(
           fn -> Notebook.eval(cell.source, notebook.bindings, notebook.env) end,
           Notebook.eval_timeout()
         ) do
      {:ok, {:ok, value, bindings, env, output}} ->
        entry = %{
          status: :ok,
          value: value,
          output: output,
          ms: System.monotonic_time(:millisecond) - started
        }

        {:ok,
         %{
           notebook
           | bindings: bindings,
             env: env,
             results: Map.put(notebook.results, cell.index, entry)
         }}

      other ->
        {:error, other}
    end
  end

  defp notebook(slug),
    do: %{
      slug: slug,
      title: Notebook.title(slug),
      cells: Notebook.cells(slug),
      bindings: [],
      env: Notebook.fresh_env(),
      results: %{},
      running_index: nil,
      task: nil,
      started_at: nil
    }

  defp params(rule) do
    [{:set_prop, _, property, value}] = rule.actions

    %{
      "id" => rule.id,
      "thing_id" => rule.thing_id,
      "trigger_op" => "prop_eq",
      "trigger_property" => "contact",
      "trigger_value" => "open",
      "action_property" => property,
      "action_value" => value
    }
  end
end
