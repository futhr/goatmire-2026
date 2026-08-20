defmodule Goatmire.RulesTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Goatmire.Rules

  @required_keys [:id, :thing_id, :trigger, :actions]

  describe "corpus shape" do
    test "every rule in every set carries the fields ExMaude requires" do
      all =
        Rules.state_conflict_pair() ++
          Rules.clean_set() ++ Rules.cascade_chain() ++ Rules.fleet(3)

      Enum.each(all, fn rule ->
        Enum.each(@required_keys, fn key ->
          assert Map.has_key?(rule, key), "#{rule[:id]} is missing #{key}"
        end)

        assert is_binary(rule.id)
        assert is_binary(rule.thing_id)
        assert is_tuple(rule.trigger)
        assert is_list(rule.actions) and rule.actions != []
      end)
    end

    test "rule ids are unique within each set" do
      Enum.each(
        [Rules.state_conflict_pair(), Rules.clean_set(), Rules.cascade_chain(), Rules.fleet(50)],
        fn set ->
          ids = Enum.map(set, & &1.id)
          assert length(Enum.uniq(ids)) == length(ids)
        end
      )
    end
  end

  describe "state_conflict_pair/0" do
    test "both rules target the same Thing and write the same property" do
      assert [a, b] = Rules.state_conflict_pair()
      assert a.thing_id == b.thing_id

      assert [{:set_prop, _, property, value_a}] = a.actions
      assert [{:set_prop, _, ^property, value_b}] = b.actions
      refute value_a == value_b, "the pair only conflicts if the written values differ"
    end
  end

  describe "clean_set/0" do
    test "no two rules share a Thing" do
      things = Enum.map(Rules.clean_set(), & &1.thing_id)
      assert length(Enum.uniq(things)) == length(things)
    end

    test "no rule's action satisfies another rule's trigger property" do
      rules = Rules.clean_set()

      written =
        rules
        |> Enum.flat_map(& &1.actions)
        |> Enum.map(fn {:set_prop, _, property, _} -> property end)
        |> MapSet.new()

      triggered =
        rules
        |> Enum.map(fn %{trigger: {_, property, _}} -> property end)
        |> MapSet.new()

      assert MapSet.disjoint?(written, triggered)
    end
  end

  describe "cascade_chain/0" do
    test "forms a closed loop back to the rule that started it" do
      rules = Rules.cascade_chain()
      assert length(rules) == 5

      # The last rule writes the same Thing the first one does, which is what
      # turns the chain into a cycle.
      first = List.first(rules)
      last = List.last(rules)
      assert last.thing_id == first.thing_id
    end
  end

  describe "fleet/1" do
    test "produces two rules per AGV" do
      assert length(Rules.fleet(10)) == 20
    end

    test "each AGV's pair conflicts with itself and nothing else" do
      rules = Rules.fleet(5)
      by_thing = Enum.group_by(rules, & &1.thing_id)

      assert map_size(by_thing) == 5
      Enum.each(by_thing, fn {_, pair} -> assert length(pair) == 2 end)
    end

    test "rejects a non-positive fleet size" do
      assert_raise FunctionClauseError, fn -> Rules.fleet(0) end
    end
  end

  describe "partition/1" do
    test "groups rules bound to the same Thing" do
      count =
        Rules.fleet(7)
        |> Rules.partition()
        |> length()

      assert count == 7
    end

    test "loses no rules" do
      rules = Rules.fleet(9) ++ Rules.clean_set()

      partitioned =
        rules
        |> Rules.partition()
        |> List.flatten()

      assert Enum.sort(Enum.map(partitioned, & &1.id)) == Enum.sort(Enum.map(rules, & &1.id))
    end

    test "an empty set partitions to nothing" do
      assert Rules.partition([]) == []
    end

    test "unrelated rules stay apart" do
      count =
        Rules.clean_set()
        |> Rules.partition()
        |> length()

      assert count == 5
    end

    test "keeps a cross-Thing cascade together" do
      # Regression: grouping by thing_id splits these, so the detector never
      # sees the pair and the gate reports clean.
      rules = [
        %{
          id: "door-opens",
          thing_id: "door-1",
          trigger: {:prop_eq, "motion", true},
          actions: [{:set_prop, "light-1", "state", "on"}],
          priority: 1
        },
        %{
          id: "light-chimes",
          thing_id: "light-1",
          trigger: {:prop_eq, "state", "on"},
          actions: [{:set_prop, "chime-1", "sound", "ding"}],
          priority: 1
        }
      ]

      assert [_] = Rules.partition(rules)
    end

    test "keeps conflicting writes to one action target together across Things" do
      rules = cross_thing_state_conflict()

      assert [_] = Rules.partition(rules)
    end

    test "keeps conflicting environment writes together across Things" do
      rules = cross_thing_environment_conflict()

      assert [_] = Rules.partition(rules)
    end

    test "keeps the whole five-rule cascade loop together" do
      assert [_] = Rules.partition(Rules.cascade_chain())
    end

    test "two readers of the same property do not interact" do
      # Both read "battery"; neither writes it. Grouping these collapsed the
      # corpus and disabled the filter.
      rules = [
        %{
          id: "r1",
          thing_id: "a",
          trigger: {:prop_lt, "battery", 20},
          actions: [{:set_prop, "a", "x", "1"}],
          priority: 1
        },
        %{
          id: "r2",
          thing_id: "b",
          trigger: {:prop_lt, "battery", 20},
          actions: [{:set_prop, "b", "y", "1"}],
          priority: 1
        }
      ]

      assert length(Rules.partition(rules)) == 2
    end

    test "follows a cascade through boolean trigger composition" do
      rules = [
        %{
          id: "writer",
          thing_id: "a",
          trigger: {:always},
          actions: [{:set_prop, "b", "armed", true}],
          priority: 1
        },
        %{
          id: "reader",
          thing_id: "b",
          trigger: {:and, {:prop_eq, "armed", true}, {:prop_gt, "temp", 10}},
          actions: [{:set_prop, "c", "z", "1"}],
          priority: 1
        }
      ]

      assert [_] = Rules.partition(rules)
    end

    test "follows an environment write into an environment trigger" do
      rules = [
        %{
          id: "heater",
          thing_id: "hvac",
          trigger: {:always},
          actions: [{:set_env, "temperature", 30}],
          priority: 1
        },
        %{
          id: "window",
          thing_id: "window-1",
          trigger: {:env_gt, "temperature", 28},
          actions: [{:set_prop, "window-1", "state", "open"}],
          priority: 1
        }
      ]

      assert [_] = Rules.partition(rules)
    end

    test "the fleet corpus still partitions per AGV" do
      corpus = Rules.fleet(40) ++ Rules.clean_set()
      assert length(Rules.partition(corpus)) == 45
    end
  end

  describe "partition soundness against the real detector" do
    @describetag :maude

    test "partitioned verification finds every conflict the whole corpus does" do
      corpora = [
        Rules.state_conflict_pair(),
        Rules.cascade_chain(),
        Rules.clean_set(),
        Rules.fleet(6),
        cross_thing_state_conflict(),
        cross_thing_environment_conflict(),
        [
          %{
            id: "door-opens",
            thing_id: "door-1",
            trigger: {:prop_eq, "motion", true},
            actions: [{:set_prop, "light-1", "state", "on"}],
            priority: 1
          },
          %{
            id: "light-chimes",
            thing_id: "light-1",
            trigger: {:prop_eq, "state", "on"},
            actions: [{:set_prop, "chime-1", "sound", "ding"}],
            priority: 1
          }
        ]
      ]

      Enum.each(corpora, fn rules ->
        {:ok, whole} = Goatmire.Verifier.verify(rules)
        {:ok, parted, _} = Goatmire.Verifier.verify_partitioned(rules)

        assert whole.status == parted.status,
               "status diverged for #{inspect(Enum.map(rules, & &1.id))}"

        assert conflict_keys(whole) == conflict_keys(parted),
               "partitioning lost or invented a conflict for " <>
                 "#{inspect(Enum.map(rules, & &1.id))}"
      end)
    end

    defp conflict_keys(verdict) do
      verdict.conflicts
      |> Enum.map(&{&1[:type], Enum.sort([&1[:rule1], &1[:rule2]])})
      |> Enum.sort()
    end
  end

  defp cross_thing_state_conflict do
    [
      %{
        id: "sensor-a-switch-on",
        thing_id: "sensor-a",
        trigger: {:always},
        actions: [{:set_prop, "shared-switch", "state", "on"}],
        priority: 1
      },
      %{
        id: "sensor-b-switch-off",
        thing_id: "sensor-b",
        trigger: {:always},
        actions: [{:set_prop, "shared-switch", "state", "off"}],
        priority: 1
      }
    ]
  end

  defp cross_thing_environment_conflict do
    [
      %{
        id: "heater-window-open",
        thing_id: "heater",
        trigger: {:always},
        actions: [{:set_env, "window_state", "open"}],
        priority: 1
      },
      %{
        id: "alarm-window-closed",
        thing_id: "alarm",
        trigger: {:always},
        actions: [{:set_env, "window_state", "closed"}],
        priority: 1
      }
    ]
  end
end
