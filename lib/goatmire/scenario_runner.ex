defmodule Goatmire.ScenarioRunner do
  @moduledoc """
  The five on-stage beats, each runnable from the CLI, a Livebook, or the
  dashboard.

    * 1 — SOTERIA-derived contact-open state conflict, caught before actuation.
    * 2 — synthetic alert storm under a staged shift, observe then enforce.
    * 3 — clean rule set.
    * 4 — a local model writes rules; `ExMaude.AI` checks them; it revises.
    * 5 — three `ExMaude.AI` policy checks, no network and no fleet.

  1, 3 and 5 need only a Maude interpreter; 2 needs the engine and fleet; 4
  needs the configured model to be reachable.
  """

  alias Goatmire.AI.RuleGenerator
  alias Goatmire.{Engine, Gate, Rules, VerificationDemo}
  alias Goatmire.Scenario.Storm

  @type result :: {:ok, map()} | {:error, term()}

  @doc """
  Runs one of the five numbered talk scenarios.

  Options by scenario: `:deploy` (1) deploys through the engine in enforce
  mode instead of only verifying; `:mode` (2) picks `:observe`, `:enforce`,
  or the default `:compare`, and the rest of the list passes through to
  `Goatmire.Scenario.Storm`; `:prompt` (4) overrides the generation request.
  Scenarios 3 and 5 take no options.
  """
  @spec run(1..5, keyword()) :: result()
  def run(scenario, opts \\ [])

  def run(1, opts) do
    rules = Rules.research_state_conflict_pair()

    if Keyword.get(opts, :deploy, false) do
      with {:ok, deployment} <-
             Engine.deploy(rules, mode: :enforce, scenario: :research_state_conflict_pair) do
        {:ok, Map.put(deployment, :rules, rules)}
      end
    else
      {:ok, verdict} = Gate.verify(rules, scenario: :research_state_conflict_pair)
      {:ok, %{verdict: verdict, rules: rules}}
    end
  end

  def run(2, opts) do
    case Keyword.get(opts, :mode, :compare) do
      :compare -> Storm.compare(opts)
      :enforce -> Storm.run(Keyword.put(opts, :mode, :enforce))
      :observe -> Storm.run(Keyword.put(opts, :mode, :observe))
      mode -> {:error, {:invalid_mode, mode}}
    end
  end

  def run(3, _) do
    {:ok, verdict} = Gate.verify(Rules.clean_set(), scenario: :scenario_3)
    {:ok, %{verdict: verdict, rules: Rules.clean_set()}}
  end

  def run(4, opts) do
    prompt =
      Keyword.get(
        opts,
        :prompt,
        "If a robot's task takes more than twice its expected duration, reassign it " <>
          "to the nearest available robot. Only proceed with the reassignment if ops approves."
      )

    RuleGenerator.run(prompt, opts)
  end

  def run(5, _), do: VerificationDemo.run()

  def run(other, _), do: {:error, {:unknown_scenario, other}}

  @doc """
  Verifies the synthetic cascade chain used by the explainer material.

  Not one of the numbered beats — it is the worked example the Livebook and
  the Q&A use when someone asks what a cascade actually looks like as a term.
  """
  @spec cascade_example() :: result()
  def cascade_example do
    {:ok, verdict} = Gate.verify(Rules.cascade_chain(), scenario: :cascade_example)
    {:ok, %{verdict: verdict, rules: Rules.cascade_chain()}}
  end
end
