defmodule GoatmireWeb.Presenter.CodeExamples do
  @moduledoc """
  Runnable evidence cards for the shortened Maude-flow slides.

  Every example evaluates against the running application. The card supports
  the spoken point without requiring the speaker to narrate implementation
  detail line by line.
  """

  @type example :: %{
          title: String.t(),
          description: String.t(),
          code: String.t(),
          source: String.t()
        }

  @doc "The runnable card for slide `n`, or `nil` when the slide has none."
  @spec example(pos_integer()) :: example() | nil
  def example(5) do
    %{
      title: "No answer admits nothing",
      description: "When the checker cannot answer, the gate withholds the rule set.",
      code: ~S"""
      alias Goatmire.{Gate, Rules}
      alias Goatmire.Verifier.Verdict

      rules = Rules.clean_set()
      unverified = %Verdict{status: :unverified, reason: :maude_unavailable}

      Gate.split_on_verdict(rules, unverified)
      """,
      source: "lib/goatmire/gate.ex"
    }
  end

  def example(6) do
    %{
      title: "Rules in, concrete conflicts out",
      description:
        "The checker evaluates the validated rule maps against its conflict definitions.",
      code: ~S"""
      alias Goatmire.Rules

      {:ok, conflicts} =
        ExMaude.IoT.detect_conflicts(Rules.research_state_conflict_pair())

      conflicts
      """,
      source: "lib/goatmire/verifier.ex"
    }
  end

  def example(7) do
    %{
      title: "A finding names the problem",
      description: "The answer includes the conflict type, both rule ids, and a readable reason.",
      code: ~S"""
      alias Goatmire.Rules

      {:ok, [conflict | _]} =
        ExMaude.IoT.detect_conflicts(Rules.research_state_conflict_pair())

      Map.take(conflict, [:type, :rule1, :rule2, :reason])
      """,
      source: "lib/goatmire/verifier.ex · ExMaude.IoT"
    }
  end

  def example(8) do
    %{
      title: "The scope travels with the answer",
      description: "A new verdict begins unverified. Clean must be earned by a completed check.",
      code: ~S"""
      %Goatmire.Verifier.Verdict{}
      """,
      source: "lib/goatmire/verifier.ex (Verdict)"
    }
  end

  def example(9) do
    %{
      title: "The live worker pool",
      description: "Maude runs in supervised operating-system processes behind a named pool.",
      code: ~S"""
      ExMaude.Pool.status()
      """,
      source: "lib/goatmire/engine/supervisor.ex"
    }
  end

  def example(10) do
    %{
      title: "The runtime executes the checked rules",
      description: "The same rule maps feed the checker and the runtime evaluator.",
      code: ~S"""
      alias Goatmire.Engine.RuleEval
      alias Goatmire.Rules

      index = RuleEval.index(Rules.research_state_conflict_pair())
      world = %{"smart-switch-1" => %{"contact" => "open"}}

      RuleEval.evaluate(index, "smart-switch-1", world)
      """,
      source: "lib/goatmire/engine/rule_eval.ex"
    }
  end

  def example(11) do
    %{
      title: "Three answers, never two",
      description: "The gate keeps clean, conflicts, and unverified separate.",
      code: ~S"""
      alias Goatmire.{Gate, Rules}

      {:ok, verdict} = Gate.verify(Rules.research_state_conflict_pair())

      %{
        status: verdict.status,
        types: Enum.map(verdict.conflicts, & &1.type),
        duration_us: verdict.duration_us
      }
      """,
      source: "lib/goatmire/verifier.ex (verify/2)"
    }
  end

  def example(12) do
    %{
      title: "Translation behavior is tested",
      description: "The runtime and model agree on what a threshold trigger means.",
      code: ~S"""
      alias Goatmire.Engine.RuleEval

      low_battery = {:prop_lt, "battery", 20}

      %{
        never_reported: RuleEval.triggered?(low_battery, %{}, %{}),
        non_numeric: RuleEval.triggered?(low_battery, %{"battery" => "low"}, %{}),
        genuinely_low: RuleEval.triggered?(low_battery, %{"battery" => 12}, %{})
      }
      """,
      source: "test/goatmire/engine/rule_eval_test.exs"
    }
  end

  def example(16) do
    %{
      title: "The checker remains deterministic",
      description:
        "Missing approval, a corrected rule, and a wrong region produce distinct answers.",
      code: ~S"""
      Goatmire.VerificationDemo.run()
      """,
      source: "lib/goatmire/ai/rule_generator.ex · lib/goatmire/verification_demo.ex"
    }
  end

  def example(_), do: nil
end
