defmodule Goatmire.Rules do
  @moduledoc """
  The demo rule corpus, as `ExMaude.IoT` rule terms.

  These maps are passed to `ExMaude.IoT.detect_conflicts/2` unchanged and
  executed unchanged by `Goatmire.Engine.RuleEval` — one representation, two
  consumers.
  """

  @type rule :: ExMaude.IoT.rule()

  @doc """
  Research-derived Scenario 1.

  SOTERIA's evaluation describes two SmartThings apps that react to the same
  contact-open event by commanding one switch both on and off. These are new
  rule ids and a controlled reproduction of that conflict shape, not copies of
  an incident or a claim about the original apps' intent.

  Source: https://www.usenix.org/conference/atc18/presentation/celik
  """
  @spec research_state_conflict_pair() :: [rule()]
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

  @doc """
  Synthetic warehouse pair used by the fleet-scale storm.
  """
  @spec state_conflict_pair() :: [rule()]
  def state_conflict_pair do
    [
      %{
        id: "agv42-low-battery-route",
        thing_id: "agv-42",
        trigger: {:prop_lt, "battery", 20},
        actions: [{:set_prop, "agv-42", "destination", "dock-7"}],
        priority: 1
      },
      %{
        id: "agv42-zone7-day-shift",
        thing_id: "agv-42",
        trigger: {:prop_gte, "hour", 9},
        actions: [{:set_prop, "agv-42", "destination", "dock-19"}],
        priority: 1
      }
    ]
  end

  @doc """
  Scenario 3: five Things, five properties, no shared writes and no action
  that satisfies another rule's trigger.
  """
  @spec clean_set() :: [rule()]
  def clean_set do
    [
      %{
        id: "conveyor-jam-halt",
        thing_id: "conveyor-3",
        trigger: {:prop_gt, "torque_nm", 180},
        actions: [{:set_prop, "conveyor-3", "motor", "stopped"}],
        priority: 0
      },
      %{
        id: "dock-19-occupancy-light",
        thing_id: "dock-19",
        trigger: {:prop_eq, "occupied", true},
        actions: [{:set_prop, "dock-19", "beacon", "amber"}],
        priority: 1
      },
      %{
        id: "cold-store-door-alarm",
        thing_id: "door-cold-1",
        trigger: {:prop_gt, "open_seconds", 120},
        actions: [{:set_prop, "door-cold-1", "buzzer", "on"}],
        priority: 1
      },
      %{
        id: "charger-bay-thermal-derate",
        thing_id: "charger-2",
        trigger: {:prop_gt, "cell_temp_c", 45},
        actions: [{:set_prop, "charger-2", "current_limit_a", "16"}],
        priority: 2
      },
      %{
        id: "packing-station-idle-dim",
        thing_id: "station-11",
        trigger: {:prop_gt, "idle_minutes", 15},
        actions: [{:set_prop, "station-11", "lighting", "dim"}],
        priority: 3
      }
    ]
  end

  @doc """
  A five-rule cycle: heat → cool → vent → intrusion → lock → HVAC off → heat.
  """
  @spec cascade_chain() :: [rule()]
  def cascade_chain do
    [
      %{
        id: "hvac-cool-on-heat",
        thing_id: "hvac-1",
        trigger: {:env_gt, "temperature", 28},
        actions: [{:set_prop, "hvac-1", "state", "cooling"}],
        priority: 1
      },
      %{
        id: "vent-open-when-cooling",
        thing_id: "vent-1",
        trigger: {:prop_eq, "state", "cooling"},
        actions: [{:set_prop, "vent-1", "state", "open"}],
        priority: 1
      },
      %{
        id: "security-suspect-open-vent",
        thing_id: "security-1",
        trigger: {:prop_eq, "state", "open"},
        actions: [{:set_prop, "security-1", "state", "suspect"}],
        priority: 1
      },
      %{
        id: "lock-doors-on-suspicion",
        thing_id: "door-1",
        trigger: {:prop_eq, "state", "suspect"},
        actions: [{:set_prop, "door-1", "state", "locked"}],
        priority: 1
      },
      %{
        id: "hvac-off-when-locked",
        thing_id: "hvac-1",
        trigger: {:prop_eq, "state", "locked"},
        actions: [{:set_prop, "hvac-1", "state", "off"}],
        priority: 0
      }
    ]
  end

  @doc """
  Two rules per AGV — a battery reroute and a Zone-7 reroute, both writing
  `destination`. `count: 200` gives 400 rules and 200 conflicting pairs.
  """
  @spec fleet(pos_integer()) :: [rule()]
  def fleet(count \\ 200) when count > 0 do
    Enum.flat_map(1..count, fn n ->
      agv = "agv-#{n}"

      [
        %{
          id: "#{agv}-low-battery-route",
          thing_id: agv,
          trigger: {:prop_lt, "battery", 20},
          actions: [{:set_prop, agv, "destination", "dock-7"}],
          priority: 1
        },
        %{
          id: "#{agv}-zone7-day-shift",
          thing_id: agv,
          trigger: {:prop_gte, "hour", 9},
          actions: [{:set_prop, agv, "destination", "dock-19"}],
          priority: 1
        }
      ]
    end)
  end

  @doc """
  Groups rules into independent verification partitions — connected components
  over an interaction graph.

  Two rules are joined when they are bound to the same Thing, write the same
  action target, or one writes a property the other triggers on (cascade).

  Grouping by `thing_id` alone is unsound: a cascade crosses Things by
  definition, so the pair lands in separate reductions, is never compared, and
  the gate reports `:clean`.

  The cascade edge matches on property name only, ignoring target Thing and
  value. That over-groups relative to the current model, deliberately — a
  tighter match would depend on model internals and fail silently if they
  changed.
  """
  @spec partition([rule()]) :: [[rule()]]
  def partition([]), do: []

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

  defp same_thing_groups(rules) do
    rules
    |> index_by(&[&1.thing_id])
    |> Map.values()
    |> Enum.filter(&(length(&1) > 1))
  end

  # Conflicts are defined by action targets, not by the Thing whose telemetry
  # triggers a rule. Two sensors can command the same actuator, and two rules
  # bound to unrelated Things can write opposing values to one environment
  # key. Those pairs must reach the same Maude reduction.
  defp same_action_target_groups(rules) do
    rules
    |> index_by(&written_targets/1)
    |> Map.values()
    |> Enum.filter(&(length(&1) > 1))
  end

  # Writer-to-reader only. Two rules that both read a property do not interact
  # through it; grouping those collapsed an 85-rule corpus into six partitions.
  defp cascade_groups(rules) do
    writers = index_by(rules, &written_properties/1)
    readers = index_by(rules, &triggered_properties/1)

    writers
    |> Enum.flat_map(fn {property, writer_ids} ->
      case Map.get(readers, property) do
        nil -> []
        reader_ids -> [Enum.uniq(writer_ids ++ reader_ids)]
      end
    end)
    |> Enum.filter(&(length(&1) > 1))
  end

  defp index_by(rules, key_fun) do
    Enum.reduce(rules, %{}, fn rule, acc ->
      Enum.reduce(key_fun.(rule), acc, fn key, acc ->
        Map.update(acc, key, [rule.id], &[rule.id | &1])
      end)
    end)
  end

  defp written_properties(rule) do
    Enum.flat_map(rule.actions, fn
      {:set_prop, _, property, _} -> [property]
      {:set_env, property, _} -> [property]
      _ -> []
    end)
  end

  defp written_targets(rule) do
    Enum.flat_map(rule.actions, fn
      {:set_prop, thing_id, property, _} -> [{:prop, thing_id, property}]
      {:set_env, property, _} -> [{:env, property}]
      _ -> []
    end)
  end

  defp triggered_properties(trigger_or_rule)

  defp triggered_properties(%{trigger: trigger}), do: triggered_properties(trigger)
  defp triggered_properties({:always}), do: []
  defp triggered_properties({:and, a, b}), do: triggered_properties(a) ++ triggered_properties(b)
  defp triggered_properties({:or, a, b}), do: triggered_properties(a) ++ triggered_properties(b)
  defp triggered_properties({:not, a}), do: triggered_properties(a)
  defp triggered_properties({_, property, _}) when is_binary(property), do: [property]
  defp triggered_properties(_), do: []

  defp union_all(parent, groups) when is_list(groups) do
    Enum.reduce(groups, parent, fn [first | rest], parent ->
      Enum.reduce(rest, parent, &union(&2, first, &1))
    end)
  end

  defp union(parent, a, b) do
    root_a = find(parent, a)
    root_b = find(parent, b)
    if root_a == root_b, do: parent, else: Map.put(parent, root_b, root_a)
  end

  defp find(parent, id) do
    case Map.fetch!(parent, id) do
      ^id -> id
      next -> find(parent, next)
    end
  end
end
