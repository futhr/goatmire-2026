defmodule Goatmire.VerifierTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Goatmire.{Rules, Verifier}
  alias Goatmire.Verifier.Verdict

  describe "split_on_verdict/2" do
    test "a clean verdict admits everything" do
      rules = Rules.clean_set()
      verdict = %Verdict{status: :clean, rule_count: length(rules)}

      assert %{admitted: ^rules, withheld: []} = Verifier.split_on_verdict(rules, verdict)
    end

    test "a conflict withholds both named rules, not just one" do
      rules = Rules.state_conflict_pair()
      [a, b] = rules

      verdict = %Verdict{
        status: :conflicts,
        conflicts: [%{type: :state_conflict, rule1: a.id, rule2: b.id, reason: "same property"}],
        rule_count: 2
      }

      assert %{admitted: [], withheld: withheld} = Verifier.split_on_verdict(rules, verdict)
      assert Enum.map(withheld, & &1.id) |> Enum.sort() == Enum.sort([a.id, b.id])
    end

    test "unrelated rules survive a conflict elsewhere in the set" do
      [a, b] = Rules.state_conflict_pair()
      clean = Rules.clean_set()
      rules = [a, b | clean]

      verdict = %Verdict{
        status: :conflicts,
        conflicts: [%{type: :state_conflict, rule1: a.id, rule2: b.id, reason: "x"}],
        rule_count: length(rules)
      }

      assert %{admitted: admitted, withheld: withheld} = Verifier.split_on_verdict(rules, verdict)
      assert length(withheld) == 2
      assert Enum.map(admitted, & &1.id) == Enum.map(clean, & &1.id)
    end

    test "a single-rule conflict with a nil counterpart withholds only that rule" do
      rules = Rules.clean_set()
      [first | _] = rules

      verdict = %Verdict{
        status: :conflicts,
        conflicts: [%{type: :approval_gate_bypass, rule1: first.id, rule2: nil, reason: "x"}],
        rule_count: length(rules)
      }

      assert %{withheld: [withheld]} = Verifier.split_on_verdict(rules, verdict)
      assert withheld.id == first.id
    end

    test "unverified fails closed — nothing is admitted" do
      rules = Rules.clean_set()
      verdict = %Verdict{status: :unverified, reason: :maude_unavailable, rule_count: 5}

      assert %{admitted: [], withheld: ^rules} = Verifier.split_on_verdict(rules, verdict)
    end
  end

  describe "verdict defaults" do
    test "a verdict always carries its scope sentence" do
      assert %Verdict{}.scope =~ "not a whole-system safety claim"
    end

    test "a bare verdict is unverified, not clean" do
      assert %Verdict{}.status == :unverified
    end
  end

  describe "invalid input" do
    test "partitioned verification returns unverified before partitioning malformed rules" do
      assert {:ok, %Verdict{status: :unverified, reason: reason}, stats} =
               Verifier.verify_partitioned([%{}])

      assert is_map(reason)
      assert reason["rule_0"] != []
      assert stats == %{partitions: 0, pairs_considered: 0, pairs_skipped: 0}
    end

    test "duplicate rule ids cannot be split into independently clean partitions" do
      [first, second | _] = Rules.clean_set()
      rules = [first, %{second | id: first.id}]

      assert {:ok,
              %Verdict{
                status: :unverified,
                reason: {:duplicate_rule_ids, [duplicate]}
              }, _} = Verifier.verify_partitioned(rules)

      assert duplicate == first.id
    end
  end

  describe "verify/2 with a real interpreter" do
    @describetag :maude

    test "the conflicting pair produces a state conflict" do
      assert {:ok, %Verdict{status: :conflicts, conflicts: [_ | _], duration_us: duration}} =
               Verifier.verify(Rules.state_conflict_pair())

      assert duration > 0
    end

    test "the SOTERIA-derived contact pair produces a state-conflict witness" do
      [first, second] = Rules.research_state_conflict_pair()

      assert {:ok, %Verdict{status: :conflicts, conflicts: conflicts}} =
               Verifier.verify(Rules.research_state_conflict_pair())

      assert Enum.any?(conflicts, fn conflict ->
               conflict.type == :state_conflict and
                 MapSet.new([conflict.rule1, conflict.rule2]) == MapSet.new([first.id, second.id])
             end)
    end

    test "the clean set produces no modeled conflict" do
      assert {:ok, %Verdict{status: :clean, conflicts: []}} = Verifier.verify(Rules.clean_set())
    end

    test "partitioned verification skips cross-Thing pairs" do
      rules = Rules.fleet(20)

      assert {:ok, %Verdict{status: :conflicts},
              %{partitions: 20, pairs_considered: considered, pairs_skipped: skipped}} =
               Verifier.verify_partitioned(rules)

      assert considered == 20
      assert skipped == 760
    end
  end
end
