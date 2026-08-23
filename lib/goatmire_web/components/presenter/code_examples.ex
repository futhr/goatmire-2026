defmodule GoatmireWeb.Presenter.CodeExamples do
  @moduledoc """
  Runnable code cards for the Maude-flow slides.

  Every example evaluates in the presenter against the running application,
  so the card is checkable on stage rather than illustrative. `source` names
  the file the call actually lives in.
  """

  @type example :: %{
          title: String.t(),
          description: String.t(),
          code: String.t(),
          source: String.t()
        }

  @doc """
  The runnable card for slide `n`, or `nil` when that slide has none.

  Each `code` string evaluates on its own against the running application.
  """
  @spec example(pos_integer()) :: example() | nil
  def example(6) do
    %{
      title: "A test samples; the gate decides",
      description:
        "The gate cannot be talked into optimism. Hand it an :unverified verdict " <>
          "and ask what may deploy: nothing is admitted, the whole set is withheld.",
      code: ~S"""
      alias Goatmire.{Gate, Rules}
      alias Goatmire.Verifier.Verdict

      rules = Rules.clean_set()
      unverified = %Verdict{status: :unverified, reason: :maude_unavailable}

      Gate.split_on_verdict(rules, unverified)
      """,
      source: "lib/goatmire/gate.ex · test/goatmire/verifier_test.exs"
    }
  end

  def example(7) do
    %{
      title: "The map that becomes four pieces",
      description:
        "One plain Elixir map per rule. These two are SOTERIA's O3 and O4: same " <>
          "trigger, same Thing and property, opposing values.",
      code: ~S"""
      Goatmire.Rules.research_state_conflict_pair()
      """,
      source: "lib/goatmire/rules.ex"
    }
  end

  def example(8) do
    %{
      title: "Reduce decides",
      description:
        "An equational reduce over the validated term — not a search. It returns a " <>
          "decision about this finite input, with the measured cost beside it.",
      code: ~S"""
      alias Goatmire.Rules

      {:ok, conflicts} =
        ExMaude.IoT.detect_conflicts(Rules.research_state_conflict_pair())

      conflicts
      """,
      source: "lib/goatmire/verifier.ex"
    }
  end

  def example(9) do
    %{
      title: "A conflict names its category",
      description:
        "A finding is not a boolean. It carries the category, both participating rule " <>
          "ids, and the reason — the witness the gate prints and a human resolves.",
      code: ~S"""
      alias Goatmire.Rules

      {:ok, [conflict | _]} =
        ExMaude.IoT.detect_conflicts(Rules.research_state_conflict_pair())

      Map.take(conflict, [:type, :rule1, :rule2, :reason])
      """,
      source: "lib/goatmire/verifier.ex · ExMaude.IoT"
    }
  end

  def example(10) do
    %{
      title: "The scope travels with the verdict",
      description:
        "A bare verdict is :unverified, never :clean — clean must be earned. The " <>
          "boundary of the claim is a field on the struct, not a caveat in a talk.",
      code: ~S"""
      %Goatmire.Verifier.Verdict{}
      """,
      source: "lib/goatmire/verifier.ex (Verdict)"
    }
  end

  def example(11) do
    %{
      title: "A pool of four, supervised like anything else",
      description:
        "Maude is a subprocess behind a worker pool in our supervision tree. This is " <>
          "the live pool on this machine, right now.",
      code: ~S"""
      ExMaude.Pool.status()
      """,
      source: "lib/goatmire/engine/supervisor.ex"
    }
  end

  def example(12) do
    %{
      title: "The runtime executes the verified term",
      description:
        "The same maps the gate reduced, evaluated by the runtime. Both rules fire on " <>
          "one contact-open event and both write `switch` — last write wins, silently. " <>
          "That is the behaviour the check exists to catch.",
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

  def example(13) do
    %{
      title: "Three verdicts, never two",
      description:
        "The gate returns a status and its witness. :clean, :conflicts, or " <>
          ":unverified — and :unverified deploys nothing.",
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

  def example(14) do
    %{
      title: "The boundary has its own tests",
      description:
        "The runtime's trigger semantics mirror the model's trigger sorts, and each " <>
          "arrow is pinned: an unseen sensor has not met a threshold, and a " <>
          "non-numeric reading satisfies no numeric comparison.",
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

  def example(15) do
    %{
      title: "Partition on interaction edges",
      description:
        "Union-find over three conservative edges: shared Thing, shared action target, " <>
          "writer-to-trigger cascade. The counters below are computed from the real " <>
          "partitions, not scripted.",
      code: ~S"""
      alias Goatmire.Rules

      rules = Rules.fleet(50)
      partitions = Rules.partition(rules)

      %{
        rules: length(rules),
        partitions: length(partitions),
        largest_partition: partitions |> Enum.map(&length/1) |> Enum.max()
      }
      """,
      source: "lib/goatmire/rules.ex (partition/1)"
    }
  end

  def example(19) do
    %{
      title: "A policy is data, and the gate reads it",
      description:
        "This policy reaches a high-impact tool with no approval constructor in its " <>
          "invocation chain. The LLM may author it; it does not judge it.",
      code: ~S"""
      unsafe = [
        %{
          id: "autodose-controller",
          agent_id: {"acme", "controller"},
          trigger: {:always},
          invocations: [{:invoke_tool, "dose", %{}, "high_impact", :eu}]
        }
      ]

      {:ok, conflicts} = ExMaude.AI.detect_conflicts(unsafe, jurisdictions: [:eu])

      Enum.map(conflicts, & &1.type)
      """,
      source: "lib/goatmire/verification_demo.ex"
    }
  end

  def example(20) do
    %{
      title: "Exactly seven, by construction",
      description:
        "Not \"misalignment\" — seven named predicates. A detector that enumerates its " <>
          "categories also states what it cannot see.",
      code: ~S"""
      seven = [
        :tool_call_conflict,
        :capability_shadowing,
        :pack_tool_composition_mismatch,
        :sovereignty_violation,
        :authority_escalation,
        :approval_gate_bypass,
        :agent_loop_cascade
      ]

      %{count: length(seven), types: seven}
      """,
      source: "ExMaude.AI moduledoc (../ex_maude)"
    }
  end

  def example(21) do
    %{
      title: "Generate, verify, revise — the gate stays deterministic",
      description:
        "The deterministic half of the loop, with no model in the path: missing " <>
          "approval is caught, adding the gate clears it, and a US invocation under " <>
          "EU/CH allowance is a sovereignty violation.",
      code: ~S"""
      Goatmire.VerificationDemo.run()
      """,
      source: "lib/goatmire/ai/rule_generator.ex · lib/goatmire/verification_demo.ex"
    }
  end

  def example(_), do: nil
end
