defmodule Goatmire.Talk.Controls do
  @moduledoc """
  The presenter action map shared by keyboard and speaker-note controls.

  This module contains no UI state. `Goatmire.Talk.Clock` owns completed
  scripted steps so every connected control surface advances the same sequence.
  """

  @scripted %{
    13 =>
      {:rules,
       [
         {:seed_deployed, "Deploy rule A"},
         {:load_example, "Load rule B"},
         {:check, "Check and create"}
       ]},
    14 => {:warehouse, [{:observe, "Observe"}, {:enforce, "Enforce"}]},
    15 => {:diagnostics, [{:diagnose, "Ask"}]},
    17 =>
      {:notebook,
       [
         {:run_next, "Cell 1"},
         {:run_next, "Cell 2"},
         {:run_next, "Cell 3"},
         {:run_next, "Cell 4"}
       ]}
  }

  @pane_actions %{
    warehouse: [{:observe, "Observe"}, {:enforce, "Enforce"}, {:clear, "Clear"}],
    rules: [
      {:seed_deployed, "Deploy rule A"},
      {:load_example, "Load rule B"},
      {:check, "Check and create"}
    ],
    diagnostics: [{:diagnose, "Ask"}],
    verify: [{:run_policy, "Run policy checks"}],
    notebook: [{:run_next, "Run next cell"}, {:reset, "Reset notebook"}]
  }

  @type pane :: :warehouse | :rules | :diagnostics | :verify | :notebook
  @type step :: atom()
  @type labeled_step :: {step(), String.t()}

  @doc "Returns the ordered scripted sequence for a slide, when it has one."
  @spec scripted(pos_integer()) :: {pane(), [labeled_step()]} | nil
  def scripted(slide), do: Map.get(@scripted, slide)

  @doc "Returns the actions supported by a live pane."
  @spec pane_actions(atom() | nil) :: [labeled_step()]
  def pane_actions(pane), do: Map.get(@pane_actions, pane, [])

  @doc "Returns the scripted and extra pane buttons for the shared touch dock."
  @spec dock_items(pos_integer(), atom() | nil, map()) ::
          {boolean(), [{String.t(), :done | :next | :todo, non_neg_integer()}], [labeled_step()]}
  def dock_items(slide, pane, play_done) do
    case scripted(slide) do
      {^pane, steps} ->
        covered =
          steps
          |> Enum.map(&elem(&1, 0))
          |> Enum.uniq()

        actions = Enum.reject(pane_actions(pane), &(elem(&1, 0) in covered))
        {true, play_steps(steps, Map.get(play_done, slide, 0)), actions}

      _ ->
        {false, [], pane_actions(pane)}
    end
  end

  @doc "Claims every unfinished scripted action through the requested index."
  @spec claim(pos_integer(), map(), non_neg_integer()) ::
          {:ok, pane(), [step()], map()} | :noop
  def claim(slide, play_done, target) do
    with {pane, steps} <- scripted(slide),
         done = Map.get(play_done, slide, 0),
         true <- target >= done and target < length(steps) do
      claimed = for index <- done..target, do: elem(Enum.at(steps, index), 0)
      {:ok, pane, claimed, Map.put(play_done, slide, target + 1)}
    else
      _ -> :noop
    end
  end

  defp play_steps(steps, done) do
    steps
    |> Enum.with_index()
    |> Enum.map(fn {{_, label}, index} -> {label, step_state(index, done), index} end)
  end

  defp step_state(index, done) when index < done, do: :done
  defp step_state(index, done) when index == done, do: :next
  defp step_state(_, _), do: :todo
end
