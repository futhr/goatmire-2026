defmodule Goatmire.AI.RuleGeneratorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Goatmire.AI.RuleGenerator

  @rejected_raw ~s({"rules":[{"id":"reassign-on-drift","agent":"fleet-ops","trigger":{"type":"prop_gt","property":"task_drift_ratio","value":2},"invocations":[{"type":"invoke_tool","name":"dispatch_robot","args":{},"capability":"high_impact","jurisdiction":"eu"}],"capability_grants":[],"authority_required":0,"priority":1}]})
  @corrected_raw ~s({"rules":[{"id":"reassign-on-drift","agent":"fleet-ops","trigger":{"type":"prop_gt","property":"task_drift_ratio","value":2},"invocations":[{"type":"require_approval","class":"reassignment_high_drift"},{"type":"invoke_tool","name":"dispatch_robot","args":{},"capability":"high_impact","jurisdiction":"eu"}],"capability_grants":[],"authority_required":0,"priority":1}]})

  describe "decode_rules/2" do
    test "decodes a well-formed payload into ExMaude.AI terms" do
      raw = ~s({"rules":[{"id":"r1","agent":"fleet-ops",
        "trigger":{"type":"prop_gt","property":"drift","value":2},
        "invocations":[{"type":"require_approval","class":"high_drift"},
        {"type":"invoke_tool","name":"dispatch","args":{},"capability":"high_impact","jurisdiction":"eu"}],
        "capability_grants":["dispatch"],"authority_required":2,"priority":1}]})

      assert {:ok, [rule]} = RuleGenerator.decode_rules(raw, "acme")
      assert rule.id == "r1"
      assert rule.agent_id == {"acme", "fleet-ops"}
      assert rule.trigger == {:prop_gt, "drift", 2}
      assert rule.authority_required == 2

      assert rule.invocations == [
               {:require_approval, "high_drift"},
               {:invoke_tool, "dispatch", %{}, "high_impact", :eu}
             ]
    end

    test "strips a markdown fence the model wrapped the JSON in" do
      raw = "```json\n" <> @corrected_raw <> "\n```"
      assert {:ok, [_]} = RuleGenerator.decode_rules(raw)
    end

    test "an unknown jurisdiction is rejected" do
      raw =
        ~s({"rules":[{"id":"r1","agent":"a","trigger":{"type":"always"},
        "invocations":[{"type":"invoke_tool","name":"t","args":{},"capability":"c","jurisdiction":"atlantis"}]}]})

      assert {:error, _} = RuleGenerator.decode_rules(raw)
    end

    test "missing optional fields fall back to safe defaults" do
      raw = ~s({"rules":[{"id":"r1","agent":"a","trigger":{"type":"always"},"invocations":[]}]})

      assert {:ok, [rule]} = RuleGenerator.decode_rules(raw)
      assert rule.capability_grants == []
      assert rule.authority_required == 0
      assert rule.priority == 1
    end

    test "an unrecognised trigger is rejected" do
      raw = ~s({"rules":[{"id":"r1","agent":"a","trigger":{"type":"vibes"},"invocations":[]}]})
      assert {:error, _} = RuleGenerator.decode_rules(raw)
    end

    test "an unknown invocation cannot stand in for high-impact approval" do
      raw = String.replace(@corrected_raw, "require_approval", "typo")
      assert {:error, _} = RuleGenerator.decode_rules(raw)
    end

    test "empty sets and missing identities are rejected" do
      assert {:error, _} = RuleGenerator.decode_rules(~s({"rules":[]}))
      raw = Jason.decode!(@corrected_raw)
      [rule] = raw["rules"]

      assert {:error, _} =
               RuleGenerator.decode_rules(Jason.encode!(%{rules: [Map.delete(rule, "id")]}))
    end

    test "malformed JSON is an error, not a partial rule set" do
      assert {:error, {:invalid_json, _}} = RuleGenerator.decode_rules("not json at all")
    end

    test "valid JSON without a rules list is an error" do
      assert {:error, {:unexpected_rule_payload, _}} =
               RuleGenerator.decode_rules(~s({"answer":42}))
    end
  end

  describe "model completion loop" do
    @describetag :maude

    test "a stubbed first response is rejected and its stubbed revision passes" do
      Req.Test.verify_on_exit!()

      Req.Test.expect(RuleGenerator, fn conn -> completion(conn, @rejected_raw) end)
      Req.Test.expect(RuleGenerator, fn conn -> completion(conn, @corrected_raw) end)

      assert {:ok, %{passes: [first, second], final_status: :clean}} =
               RuleGenerator.run("reassign an overrunning task")

      assert first.status == :conflicts
      assert Enum.any?(first.conflicts, &(&1[:type] == :approval_gate_bypass))

      assert second.status == :clean
      assert second.conflicts == []

      assert Enum.any?(second.rules, fn rule ->
               Enum.any?(rule.invocations, &match?({:require_approval, _class}, &1))
             end)
    end
  end

  describe "provider failures" do
    test "an unreachable model is reported as unreachable, never as clean" do
      Req.Test.stub(RuleGenerator, &Req.Test.transport_error(&1, :econnrefused))

      log =
        capture_log(fn ->
          assert {:error, {:llm_unreachable, _}} =
                   RuleGenerator.run("anything", max_attempts: 1)
        end)

      assert log =~ "transport failure"
    end

    test "an unexpected response body is an error" do
      Req.Test.stub(RuleGenerator, fn conn -> Req.Test.json(conn, %{"oops" => true}) end)

      assert {:error, {:unexpected_llm_response, _}} =
               RuleGenerator.run("anything", max_attempts: 1)
    end
  end

  defp completion(conn, content) do
    Req.Test.json(conn, %{"choices" => [%{"message" => %{"content" => content}}]})
  end
end
