defmodule Goatmire.Engine.RuleEvalTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Goatmire.Engine.RuleEval

  describe "triggered?/3" do
    test "numeric comparisons" do
      props = %{"battery" => 18}

      assert RuleEval.triggered?({:prop_lt, "battery", 20}, props, %{})
      refute RuleEval.triggered?({:prop_gt, "battery", 20}, props, %{})
      assert RuleEval.triggered?({:prop_lte, "battery", 18}, props, %{})
      assert RuleEval.triggered?({:prop_gte, "battery", 18}, props, %{})
    end

    test "an unreported property never satisfies a threshold" do
      refute RuleEval.triggered?({:prop_lt, "battery", 20}, %{}, %{})
      refute RuleEval.triggered?({:prop_gt, "battery", 20}, %{}, %{})
    end

    test "a non-numeric reading does not satisfy a numeric comparison" do
      refute RuleEval.triggered?({:prop_lt, "battery", 20}, %{"battery" => "low"}, %{})
    end

    test "equality is exact" do
      assert RuleEval.triggered?({:prop_eq, "mode", "charging"}, %{"mode" => "charging"}, %{})
      refute RuleEval.triggered?({:prop_eq, "mode", "charging"}, %{"mode" => "driving"}, %{})
    end

    test "environment predicates read the env map" do
      assert RuleEval.triggered?({:env_gt, "temperature", 28}, %{}, %{"temperature" => 30})
      refute RuleEval.triggered?({:env_gt, "temperature", 28}, %{"temperature" => 30}, %{})
    end

    test "boolean composition" do
      props = %{"battery" => 18, "hour" => 10}

      assert RuleEval.triggered?(
               {:and, {:prop_lt, "battery", 20}, {:prop_gte, "hour", 9}},
               props,
               %{}
             )

      assert RuleEval.triggered?(
               {:or, {:prop_lt, "battery", 5}, {:prop_gte, "hour", 9}},
               props,
               %{}
             )

      assert RuleEval.triggered?({:not, {:prop_lt, "battery", 5}}, props, %{})
    end

    test "always holds and unknown shapes do not" do
      assert RuleEval.triggered?({:always}, %{}, %{})
      refute RuleEval.triggered?({:regex_match, "name", "x"}, %{"name" => "x"}, %{})
    end
  end

  describe "evaluate/3" do
    setup do
      rules = [
        %{
          id: "route-on-low-battery",
          thing_id: "agv-42",
          trigger: {:prop_lt, "battery", 20},
          actions: [{:set_prop, "agv-42", "destination", "dock-7"}],
          priority: 1
        },
        %{
          id: "avoid-zone-7",
          thing_id: "agv-42",
          trigger: {:prop_gte, "hour", 9},
          actions: [{:set_prop, "agv-42", "destination", "dock-19"}],
          priority: 1
        }
      ]

      %{index: RuleEval.index(rules)}
    end

    test "returns only the rules whose trigger holds", %{index: index} do
      world = %{"agv-42" => %{"battery" => 18, "hour" => 3}}
      assert {["route-on-low-battery"], actions} = RuleEval.evaluate(index, "agv-42", world)
      assert actions == [{:set_prop, "agv-42", "destination", "dock-7"}]
    end

    test "both rules fire when both triggers hold, in rule order", %{index: index} do
      world = %{"agv-42" => %{"battery" => 18, "hour" => 10}}

      assert {["route-on-low-battery", "avoid-zone-7"], actions} =
               RuleEval.evaluate(index, "agv-42", world)

      # Last write wins at runtime — which is exactly the silent behaviour the
      # deployment-time state-conflict check exists to surface.
      assert actions == [
               {:set_prop, "agv-42", "destination", "dock-7"},
               {:set_prop, "agv-42", "destination", "dock-19"}
             ]
    end

    test "a Thing with no bound rules yields nothing", %{index: index} do
      assert {[], []} = RuleEval.evaluate(index, "agv-99", %{})
    end
  end

  describe "world helpers" do
    test "put and get a reading" do
      world = RuleEval.put_reading(%{}, "agv-1", "battery", 42)
      assert RuleEval.get_reading(world, "agv-1", "battery") == 42
      assert RuleEval.get_reading(world, "agv-1", "missing") == nil
      assert RuleEval.get_reading(world, "agv-2", "battery") == nil
    end
  end
end
