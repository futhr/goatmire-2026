defmodule Goatmire.RulesPartitionPropertyTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Goatmire.Rules

  @moduletag :property

  property "partitioning is lossless and keeps every interaction edge connected" do
    check all(fields <- list_of(rule_fields(), min_length: 1, max_length: 36), max_runs: 150) do
      rules =
        fields
        |> Enum.with_index(1)
        |> Enum.map(fn {{thing, trigger_property, target, action_property, value}, index} ->
          %{
            id: "generated-#{index}",
            thing_id: thing,
            trigger: {:prop_eq, trigger_property, value},
            actions: [{:set_prop, target, action_property, value}],
            priority: 1
          }
        end)

      partitions = Rules.partition(rules)
      flattened = List.flatten(partitions)

      assert Enum.sort_by(flattened, & &1.id) == Enum.sort_by(rules, & &1.id)
      assert length(Enum.uniq_by(flattened, & &1.id)) == length(rules)

      membership =
        partitions
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {partition, index}, acc ->
          Enum.reduce(partition, acc, &Map.put(&2, &1.id, index))
        end)

      for {left, left_index} <- Enum.with_index(rules),
          right <- Enum.drop(rules, left_index + 1),
          interacts?(left, right) do
        assert membership[left.id] == membership[right.id],
               "interaction edge was split: #{left.id} ↔ #{right.id}"
      end
    end
  end

  property "the generated fleet always partitions into one pair per AGV" do
    check all(fleet_size <- integer(1..300), max_runs: 100) do
      rules = Rules.fleet(fleet_size)
      partitions = Rules.partition(rules)

      assert length(partitions) == fleet_size
      assert Enum.all?(partitions, &(length(&1) == 2))

      assert Enum.all?(partitions, fn pair ->
               thing_ids = Enum.map(pair, & &1.thing_id)
               length(Enum.uniq(thing_ids)) == 1
             end)
    end
  end

  defp rule_fields do
    fixed_list([
      member_of(~w(agv-1 agv-2 door-1 sensor-1)),
      member_of(~w(battery state contact temperature destination)),
      member_of(~w(agv-1 agv-2 switch-1 hvac-1)),
      member_of(~w(state temperature destination alarm battery)),
      one_of([integer(-3..3), boolean(), member_of(~w(on off open closed))])
    ])
    |> map(&List.to_tuple/1)
  end

  defp interacts?(left, right) do
    left.thing_id == right.thing_id or
      not MapSet.disjoint?(written_targets(left), written_targets(right)) or
      not MapSet.disjoint?(written_properties(left), triggered_properties(right)) or
      not MapSet.disjoint?(written_properties(right), triggered_properties(left))
  end

  defp written_targets(rule) do
    rule.actions
    |> Enum.map(fn {:set_prop, thing_id, property, _} -> {:prop, thing_id, property} end)
    |> MapSet.new()
  end

  defp written_properties(rule) do
    rule.actions
    |> Enum.map(fn {:set_prop, _, property, _} -> property end)
    |> MapSet.new()
  end

  defp triggered_properties(%{trigger: {_, property, _}}), do: MapSet.new([property])
end
