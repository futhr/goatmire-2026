defmodule GoatmireWeb.Presenter.CodeExamples do
  @moduledoc """
  Right-panel code cards pairing each Maude-flow slide with the code that
  backs it. Every excerpt is quoted from this repository (or ExMaude's docs
  where noted) — the card's claim is checkable at the cited path.
  """

  @spec example(pos_integer()) ::
          %{title: String.t(), description: String.t(), code: String.t(), source: String.t()}
          | nil
  def example(6) do
    %{
      title: "A test samples; the gate decides",
      description:
        "The suite can only fail closed by scripting the gate — on a machine where " <>
          "Maude works, :unverified never happens by accident. The test asserts the " <>
          "property the talk depends on: an availability failure admits nothing.",
      code: ~S"""
      test "unverified fails closed — nothing is admitted" do
        rules = Rules.clean_set()

        verdict = %Verdict{
          status: :unverified,
          reason: :maude_unavailable,
          rule_count: 5
        }

        assert %{admitted: [], withheld: ^rules} =
                 Verifier.split_on_verdict(rules, verdict)
      end
      """,
      source: "test/goatmire/verifier_test.exs"
    }
  end

  def example(7) do
    %{
      title: "The map that becomes four pieces",
      description:
        "One plain Elixir map per rule. The encoder turns trigger and actions into " <>
          "the sorts, operators, equations, and rewrite rules of the bundled model — " <>
          "these two are SOTERIA's O3 and O4, verbatim.",
      code: ~S"""
      def research_state_conflict_pair do
        [
          %{
            id: "soteria-o3-contact-open-turn-on",
            thing_id: "smart-switch-1",
            trigger: {:prop_eq, "contact", "open"},
            actions: [{:set_prop, "smart-switch-1", "switch", "on"}],
            priority: 1
          },
          %{
            id: "soteria-o4-contact-open-turn-off",
            thing_id: "smart-switch-1",
            trigger: {:prop_eq, "contact", "open"},
            actions: [{:set_prop, "smart-switch-1", "switch", "off"}],
            priority: 1
          }
        ]
      end
      """,
      source: "lib/goatmire/rules.ex"
    }
  end

  def example(8) do
    %{
      title: "The detector call is a reduction",
      description:
        "ExMaude.IoT.detect_conflicts/2 is an equational reduce, not a state search: " <>
          "the answer is decided, not sampled. Validation runs first so a malformed " <>
          "set becomes :unverified before Maude is ever asked.",
      code: ~S"""
      defp validated_detect(rules, opts) do
        with :ok <- validate_rule_set(rules) do
          safe_detect(rules, opts)
        end
      end

      # ExMaude.IoT.detect_conflicts(rules)
      # => {:ok, []}                    reduce decided: no modelled conflict
      # => {:ok, [%{type: :state_conflict, ...}]}
      # => {:error, reason}             the detector could not run
      """,
      source: "lib/goatmire/verifier.ex"
    }
  end

  def example(9) do
    %{
      title: "A conflict names its category",
      description:
        "Each finding carries a type from the model's four categories, both rule ids, " <>
          "and a reason — the witness the dashboard prints under the verdict.",
      code: ~S"""
      {:ok, conflicts} = ExMaude.IoT.detect_conflicts(rules)

      # conflicts =>
      # [
      #   %{
      #     type: :state_conflict,
      #     rule1: "soteria-o3-contact-open-turn-on",
      #     rule2: "soteria-o4-contact-open-turn-off",
      #     reason: "same trigger writes switch=on and switch=off"
      #   }
      # ]
      # types: :state_conflict | :environment_conflict
      #        | :cascade | :state_env_cascade
      """,
      source: "lib/goatmire/verifier.ex (Verdict.conflicts)"
    }
  end

  def example(10) do
    %{
      title: "The scope travels with the verdict",
      description:
        "The claim's boundary is a field on the struct, not a caveat in a talk. A " <>
          "bare verdict defaults to :unverified — clean must be earned.",
      code: ~S"""
      defstruct status: :unverified,
                conflicts: [],
                rule_count: 0,
                duration_us: 0,
                reason: nil,
                scope:
                  "Evaluated against the four conflict types encoded " <>
                    "in the bundled iot-rules.maude model. A clean " <>
                    "result is not a whole-system safety claim."
      """,
      source: "lib/goatmire/verifier.ex (Verdict)"
    }
  end

  def example(11) do
    %{
      title: "A pool of four, supervised like anything else",
      description:
        "Maude is a subprocess behind a worker pool under rest_for_one: if the pool " <>
          "restarts, the engine restarts with it. Templates preload at start so the " <>
          "first reduction never races a busy worker.",
      code: ~S"""
      def init(_opts) do
        children =
          [ex_maude_child_spec(), Goatmire.Engine] ++ vda5050_children()

        Supervisor.init(children,
          strategy: :rest_for_one,
          max_restarts: 10,
          max_seconds: 10
        )
      end

      defp ex_maude_child_spec do
        preload_maude_templates()

        ExMaude.Pool.child_spec(pool_size: 4, pool_max_overflow: 0)
      end
      """,
      source: "lib/goatmire/engine/supervisor.ex"
    }
  end

  def example(12) do
    %{
      title: "The runtime executes the verified term",
      description:
        "RuleEval evaluates the same maps the gate reduced — no second translation. " <>
          "Last-write-wins in action order is exactly the silent behaviour the " <>
          "state-conflict check exists to catch before deployment.",
      code: ~S"""
      def evaluate(index, thing_id, world) do
        props = Map.get(world, thing_id, %{})
        env = Map.get(world, "__env__", %{})

        index
        |> Map.get(thing_id, [])
        |> Enum.reduce({[], []}, fn rule, {fired, actions} ->
          if triggered?(rule.trigger, props, env) do
            {[rule.id | fired], actions ++ rule.actions}
          else
            {fired, actions}
          end
        end)
      end
      """,
      source: "lib/goatmire/engine/rule_eval.ex"
    }
  end

  def example(13) do
    %{
      title: "Three verdicts, never two",
      description:
        "The case has three branches and the third is not an error path — it is a " <>
          "verdict. An interpreter timeout becomes :unverified, and :unverified " <>
          "deploys nothing.",
      code: ~S"""
      verdict =
        case validated_detect(rules, maude_opts) do
          {:ok, []} ->
            %Verdict{status: :clean, rule_count: length(rules)}

          {:ok, conflicts} ->
            %Verdict{
              status: :conflicts,
              conflicts: conflicts,
              rule_count: length(rules)
            }

          {:error, reason} ->
            %Verdict{
              status: :unverified,
              reason: reason,
              rule_count: length(rules)
            }
        end
      """,
      source: "lib/goatmire/verifier.ex (verify/2)"
    }
  end

  def example(14) do
    %{
      title: "The boundary has its own tests",
      description:
        "The runtime's trigger semantics mirror the model's trigger sorts, and each " <>
          "arrow is pinned by a test: an unseen sensor has not met a threshold, and a " <>
          "non-numeric reading satisfies no numeric comparison.",
      code: ~S"""
      test "an unreported property never satisfies a threshold" do
        refute RuleEval.triggered?({:prop_lt, "battery", 20}, %{}, %{})
        refute RuleEval.triggered?({:prop_gt, "battery", 20}, %{}, %{})
      end

      test "a non-numeric reading does not satisfy a numeric comparison" do
        refute RuleEval.triggered?(
                 {:prop_lt, "battery", 20},
                 %{"battery" => "low"},
                 %{}
               )
      end
      """,
      source: "test/goatmire/engine/rule_eval_test.exs"
    }
  end

  def example(15) do
    %{
      title: "Partition on interaction edges",
      description:
        "Union-find over three conservative edges: shared Thing, shared action " <>
          "target, writer-to-trigger cascade. The counters on screen are computed " <>
          "from the real partitions, not scripted.",
      code: ~S"""
      def partition(rules) do
        parent = Map.new(rules, &{&1.id, &1.id})

        parent =
          parent
          |> union_all(same_thing_groups(rules))
          |> union_all(same_action_target_groups(rules))
          |> union_all(cascade_groups(rules))

        rules
        |> Enum.group_by(&find(parent, &1.id))
        |> Map.values()
      end

      pairs_skipped: pair_count(total) - pairs_considered
      """,
      source: "lib/goatmire/rules.ex · lib/goatmire/verifier.ex"
    }
  end

  def example(19) do
    %{
      title: "A policy is data, and the gate reads it",
      description:
        "The unsafe policy reaches a high-impact tool with no approval constructor in " <>
          "its invocation chain; the gated one differs by a single tuple. The LLM may " <>
          "author either — it judges neither.",
      code: ~S"""
      defp unsafe_policy do
        [
          %{
            id: "autodose-controller",
            agent_id: {"acme", "controller"},
            trigger: {:always},
            invocations: [
              {:invoke_tool, "dose", %{}, "high_impact", :eu}
            ]
          }
        ]
      end

      defp gated_policy do
        [
          %{
            id: "autodose-controller",
            agent_id: {"acme", "controller"},
            trigger: {:always},
            invocations: [
              {:require_approval, "dosing_high_delta"},
              {:invoke_tool, "dose", %{}, "high_impact", :eu}
            ]
          }
        ]
      end
      """,
      source: "lib/goatmire/verification_demo.ex"
    }
  end

  def example(20) do
    %{
      title: "Exactly seven, by construction",
      description:
        "The AI-policy model encodes seven conflict types — not \"misalignment\", " <>
          "seven named predicates. A detector that names its categories also names " <>
          "what it cannot see.",
      code: ~S"""
      # ExMaude.AI detects seven conflict types:
      #
      #   :tool_call_conflict              conflicting required args
      #   :capability_shadowing            equal-priority double grant
      #   :pack_tool_composition_mismatch  type-shape signature clash
      #   :sovereignty_violation           jurisdiction outside the set
      #   :authority_escalation            grant above required authority
      #   :approval_gate_bypass            high-impact path, no gate
      #   :agent_loop_cascade              grant feeds a requirement

      {:ok, conflicts} =
        ExMaude.AI.detect_conflicts(policy, jurisdictions: [:eu])
      """,
      source: "ExMaude.AI moduledoc (../ex_maude)"
    }
  end

  def example(21) do
    %{
      title: "Generate, verify, revise — the gate stays deterministic",
      description:
        "One generate→verify round per attempt: a conflicted set goes back to the " <>
          "model with the verdict as the revision prompt, and a detector failure is " <>
          ":unverified — the author never grades its own work.",
      code: ~S"""
      {status, conflicts} = verify(rules, context.jurisdictions)

      if status == :conflicts and attempt < context.max_attempts do
        messages
        |> Kernel.++([
          %{role: "assistant", content: raw},
          %{role: "user", content: revision_prompt(conflicts)}
        ])
        |> attempt(attempt + 1, passes, context)
      end

      defp verify(rules, jurisdictions) do
        case ExMaude.AI.detect_conflicts(rules, jurisdictions: jurisdictions) do
          {:ok, []} -> {:clean, []}
          {:ok, conflicts} -> {:conflicts, conflicts}
          {:error, reason} -> {:unverified, [%{type: :unverified, ...}]}
        end
      end
      """,
      source: "lib/goatmire/ai/rule_generator.ex"
    }
  end

  def example(_n), do: nil
end
