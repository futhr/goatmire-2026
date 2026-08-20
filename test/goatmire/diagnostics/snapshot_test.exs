defmodule Goatmire.Diagnostics.SnapshotTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.Diagnostics.{BeamlensSupervisor, Sampler, Skill, Snapshot}

  test "the supervised coordinator and operator both have the real six-iteration cap" do
    coordinator = :sys.get_state(Beamlens.Coordinator)
    assert coordinator.max_iterations == BeamlensSupervisor.max_iterations()
    assert coordinator.skills == [Skill]

    assert [{operator_pid, _}] =
             Registry.lookup(Beamlens.OperatorRegistry, Skill)

    operator = :sys.get_state(operator_pid)
    assert operator.max_iterations == BeamlensSupervisor.max_iterations()
    assert operator.skill == Skill
    assert Beamlens.Supervisor.registered_skills() == [Skill]
  end

  test "reset replaces both bounded agents after a cancelled diagnosis" do
    coordinator_before = Process.whereis(Beamlens.Coordinator)
    [{operator_before, _}] = Registry.lookup(Beamlens.OperatorRegistry, Skill)

    assert :ok = BeamlensSupervisor.reset()

    coordinator_after = Process.whereis(Beamlens.Coordinator)
    [{operator_after, _}] = Registry.lookup(Beamlens.OperatorRegistry, Skill)

    refute coordinator_after == coordinator_before
    refute operator_after == operator_before
    assert :sys.get_state(coordinator_after).max_iterations == 6
    assert :sys.get_state(operator_after).max_iterations == 6
  end

  test "returns a bounded JSON-safe runtime and verifier snapshot" do
    snapshot = Snapshot.read(:one_minute)

    assert snapshot.window_seconds == 60
    assert is_map(snapshot.current.beam)
    assert is_map(snapshot.current.engine)
    assert is_map(snapshot.current.maude.pool)
    assert {:ok, _} = Jason.encode(snapshot)
  end

  test "rejects unbounded windows" do
    assert_raise ArgumentError, fn -> Snapshot.read(301) end
  end

  test "BeamLens skill exposes only read-only diagnostic callbacks" do
    callbacks = Skill.callbacks()

    assert Map.keys(callbacks) |> Enum.sort() ==
             ~w(goatmire_current_verification goatmire_recent_alerts goatmire_snapshot)

    assert Skill.title() == "Goatmire simulation"
    assert Skill.description() =~ "Maude verdicts"
    assert Skill.system_prompt() =~ "Distinguish observations from inferences"
    refute Skill.callback_docs() =~ "deploy("
    skill_snapshot = Skill.snapshot()
    assert {:ok, _} = Jason.encode(skill_snapshot)
    assert length(skill_snapshot.recent_events) <= 8
    refute Enum.any?(skill_snapshot.recent_events, &(&1.event == "goatmire.engine.event"))

    assert %{window_seconds: 300} = callbacks["goatmire_snapshot"].("999")
    assert %{window_seconds: 10} = callbacks["goatmire_snapshot"].(1.2)
    assert %{available: available} = callbacks["goatmire_current_verification"].()
    assert is_boolean(available)
    assert %{alerts: alerts, count: count} = callbacks["goatmire_recent_alerts"].("invalid")
    assert is_list(alerts)
    assert count <= 12
  end

  test "a standalone sampler bounds its history" do
    name = :goatmire_bounded_snapshot_sampler_test
    pid = start_supervised!({Sampler, name: name, sample_ms: 5, history_limit: 3})
    Process.sleep(30)

    snapshot = GenServer.call(pid, {:snapshot, 10})
    assert snapshot.sample_count <= 3
  end
end
