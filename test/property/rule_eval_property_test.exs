defmodule Goatmire.Engine.RuleEvalPropertyTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Goatmire.Engine.RuleEval

  @moduletag :property

  property "numeric trigger operators agree with Elixir ordering" do
    check all(
            actual <- integer(-1_000_000..1_000_000),
            expected <- integer(-1_000_000..1_000_000),
            operator <- member_of([:prop_gt, :prop_lt, :prop_gte, :prop_lte]),
            max_runs: 250
          ) do
      trigger = {operator, "reading", expected}
      props = %{"reading" => actual}

      oracle =
        case operator do
          :prop_gt -> actual > expected
          :prop_lt -> actual < expected
          :prop_gte -> actual >= expected
          :prop_lte -> actual <= expected
        end

      assert RuleEval.triggered?(trigger, props, %{}) == oracle
      refute RuleEval.triggered?(trigger, %{}, %{})
    end
  end

  property "boolean trigger composition follows boolean algebra" do
    check all(left <- boolean(), right <- boolean(), max_runs: 150) do
      props = %{"left" => left, "right" => right}
      a = {:prop_eq, "left", true}
      b = {:prop_eq, "right", true}

      assert RuleEval.triggered?({:and, a, b}, props, %{}) == (left and right)
      assert RuleEval.triggered?({:or, a, b}, props, %{}) == (left or right)
      assert RuleEval.triggered?({:not, a}, props, %{}) == not left
    end
  end

  property "world writes round-trip arbitrary bounded sensor values" do
    check all(
            thing_id <- safe_identifier(),
            property <- safe_identifier(),
            value <- one_of([integer(), boolean(), string(:alphanumeric, max_length: 48)]),
            max_runs: 200
          ) do
      world = RuleEval.put_reading(%{}, thing_id, property, value)
      assert RuleEval.get_reading(world, thing_id, property) == value
    end
  end

  property "evaluation preserves source order for simultaneously firing rules" do
    check all(count <- integer(1..80), max_runs: 100) do
      rules =
        for n <- 1..count do
          %{
            id: "rule-#{n}",
            thing_id: "agv-1",
            trigger: {:always},
            actions: [{:set_prop, "agv-1", "sequence", n}],
            priority: 1
          }
        end

      index = RuleEval.index(rules)
      {fired, actions} = RuleEval.evaluate(index, "agv-1", %{})

      assert fired == Enum.map(rules, & &1.id)
      assert actions == Enum.flat_map(rules, & &1.actions)
    end
  end

  defp safe_identifier do
    string(:alphanumeric, min_length: 1, max_length: 32)
  end
end
