defmodule Goatmire.Scenario.StormTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Goatmire.{Fleet, Scenario.Storm, StubVerifier}

  setup do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    Fleet.stop_all()

    on_exit(fn ->
      Fleet.stop_all()
      Application.delete_env(:goatmire, :verifier)
    end)

    :ok
  end

  test "runs the staged shift change through the deployment gate" do
    assert {:ok, summary} =
             Storm.run(fleet_size: 3, duration_seconds: 1, tick_ms: 20, drain_pct: 18)

    assert summary.mode == :enforce
    assert summary.fleet_size == 3
    assert summary.duration_seconds == 1
    assert summary.verdict.status == :clean
    assert summary.rules_deployed > 0
    assert summary.events > 0
    assert summary.wall_clock_ms >= 1_000
    assert Fleet.count() == 0
  end

  test "can leave the fleet running for dashboard inspection" do
    assert {:ok, summary} =
             Storm.run(
               mode: :observe,
               fleet_size: 1,
               duration_seconds: 1,
               tick_ms: 25,
               keep_fleet: true
             )

    assert summary.mode == :observe
    assert Fleet.count() == 6
  end

  test "rejects invalid load options before changing fleet state" do
    assert {:ok, 1} = Fleet.start_simulated_fleet(1, tick_ms: 0)

    assert_raise ArgumentError, ~r/fleet_size must be a positive integer/, fn ->
      Storm.run(fleet_size: 0, duration_seconds: 1, tick_ms: 20)
    end

    assert_raise ArgumentError, ~r/duration_seconds must be a positive integer/, fn ->
      Storm.run(fleet_size: 1, duration_seconds: 0, tick_ms: 20)
    end

    assert_raise ArgumentError, ~r/tick_ms must be a positive integer/, fn ->
      Storm.run(fleet_size: 1, duration_seconds: 1, tick_ms: -1)
    end

    assert_raise ArgumentError, ~r/drain_pct must be a number between 0 and 100/, fn ->
      Storm.run(fleet_size: 1, duration_seconds: 1, tick_ms: 20, drain_pct: 101)
    end

    assert Fleet.count() == 1
  end
end
