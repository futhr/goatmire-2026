defmodule Goatmire.ScenarioRunnerTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Goatmire.{Engine, Rules, ScenarioRunner, StubVerifier}

  setup do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    :ok = Engine.undeploy()

    on_exit(fn ->
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
    end)

    :ok
  end

  defp conflicting_pair_verdict do
    [a, b] = Rules.research_state_conflict_pair()
    {:conflicts, [%{type: :state_conflict, rule1: a.id, rule2: b.id, reason: "same property"}]}
  end

  test "scenario 1 verifies the pair without deploying by default" do
    StubVerifier.set(conflicting_pair_verdict())

    assert {:ok, %{verdict: %{status: :conflicts}, rules: rules}} = ScenarioRunner.run(1)
    assert rules == Rules.research_state_conflict_pair()
    assert Engine.status().deployed_count == 0
  end

  test "scenario 1 with deploy: true routes through the gate" do
    StubVerifier.set(conflicting_pair_verdict())

    assert {:ok, %{deployed: 0, verdict: %{status: :conflicts}}} =
             ScenarioRunner.run(1, deploy: true)
  end

  test "scenario 3 verifies the clean set" do
    StubVerifier.set(:clean)

    assert {:ok, %{verdict: %{status: :clean, conflicts: []}, rules: rules}} =
             ScenarioRunner.run(3)

    assert length(rules) == 5
  end

  test "cascade_example verifies the five-rule loop" do
    StubVerifier.set(:clean)

    assert {:ok, %{rules: rules}} = ScenarioRunner.cascade_example()
    assert length(rules) == 5
  end

  test "an unknown scenario number is an error, not a crash" do
    assert {:error, {:unknown_scenario, 9}} = ScenarioRunner.run(9)
  end

  describe "scenario 5" do
    @describetag :maude

    test "returns the three exact checked outcomes" do
      assert {:ok, %{scenario: 5, checks: checks}} = ScenarioRunner.run(5)

      assert checks.missing_approval_gate == [:approval_gate_bypass]
      assert checks.explicit_approval_gate == []
      assert checks.outside_jurisdiction == [:sovereignty_violation]
    end
  end
end
