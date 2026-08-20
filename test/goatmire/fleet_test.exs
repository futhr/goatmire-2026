defmodule Goatmire.FleetTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Goatmire.Device.Station
  alias Goatmire.{Fleet, Transport}

  setup do
    Fleet.stop_all()
    on_exit(&Fleet.stop_all/0)
    :ok
  end

  test "starts and stops simulated devices" do
    assert Fleet.count() == 0
    assert {:ok, 5} = Fleet.start_simulated_fleet(5, tick_ms: 0)
    assert Fleet.count() == 5

    assert :ok = Fleet.stop("agv-3")
    assert Fleet.count() == 4
    assert Fleet.whereis("agv-3") == nil
  end

  test "a zero-sized fleet is empty rather than an inverted range" do
    assert {:ok, 0} = Fleet.start_simulated_fleet(0, tick_ms: 0)
    assert Fleet.count() == 0
  end

  test "rejects negative counts and offsets before starting devices" do
    assert_raise ArgumentError, ~r/fleet count must be a non-negative integer/, fn ->
      Fleet.start_simulated_fleet(-1, tick_ms: 0)
    end

    assert_raise ArgumentError, ~r/fleet offset must be a non-negative integer/, fn ->
      Fleet.start_simulated_fleet(1, offset: -1, tick_ms: 0)
    end

    assert Fleet.count() == 0
  end

  test "stopping an unknown device is an explicit error, not a crash" do
    assert {:error, :not_found} = Fleet.stop("agv-nope")
  end

  test "offset keeps thing_id ranges disjoint across nodes" do
    {:ok, 3} = Fleet.start_simulated_fleet(3, offset: 100, tick_ms: 0)

    ids =
      Fleet.list()
      |> Enum.map(& &1.thing_id)
      |> Enum.sort()

    assert ids == ["agv-101", "agv-102", "agv-103"]
  end

  test "the global VDA 5050 switch reaches auto-started fleet devices" do
    previous = Application.get_env(:goatmire, :vda5050_enabled)
    Application.put_env(:goatmire, :vda5050_enabled, true)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:goatmire, :vda5050_enabled)
      else
        Application.put_env(:goatmire, :vda5050_enabled, previous)
      end
    end)

    assert {:ok, 1} = Fleet.start_simulated_fleet(1, tick_ms: 0)
    assert %{vda5050: true} = :sys.get_state(Fleet.whereis("agv-1"))
  end

  test "snapshot reports each device's physical state" do
    {:ok, 2} = Fleet.start_simulated_fleet(2, tick_ms: 0)

    assert [first, second] = Fleet.snapshot()
    assert first.thing_id == "agv-1"
    assert second.thing_id == "agv-2"

    Enum.each([first, second], fn device ->
      assert device.kind == :simulated
      assert device.status == :online
      assert is_number(device.battery)
      assert %{x: _, y: _} = device.position
      assert device.zone =~ ~r/^zone-[1-9]$/
    end)
  end

  test "snapshot_sample is bounded and prioritizes physical devices" do
    {:ok, 4} = Fleet.start_simulated_fleet(4, tick_ms: 0)
    {:ok, _} = Fleet.attach_real("bench-agv")

    assert [physical, simulated] = Fleet.snapshot_sample(2)
    assert physical.thing_id == "bench-agv"
    assert physical.kind == :real
    assert simulated.thing_id == "agv-1"
  end

  test "list is sorted so the dashboard does not reshuffle between renders" do
    {:ok, 12} = Fleet.start_simulated_fleet(12, tick_ms: 0)
    ids = Enum.map(Fleet.list(), & &1.thing_id)
    assert ids == Enum.sort(ids)
  end

  describe "real devices" do
    test "a declared device is present before its first reading" do
      assert {:ok, _} = Fleet.attach_real("bench-agv", stale_after_ms: 50)

      assert [device] = Fleet.snapshot()
      assert device.kind == :real
      assert device.status == :never_seen
      assert device.last_seen_ms_ago == nil
    end

    test "a reading brings it online" do
      {:ok, _} = Fleet.attach_real("bench-agv", stale_after_ms: 10_000)
      Transport.publish_telemetry("bench-agv", "battery", 77)
      Process.sleep(50)

      assert [device] = Fleet.snapshot()
      assert device.status == :online
      assert device.battery == 77
    end

    test "silence past the threshold reads as stale, not as absent" do
      {:ok, _} = Fleet.attach_real("bench-agv", stale_after_ms: 20)
      Transport.publish_telemetry("bench-agv", "battery", 77)
      Process.sleep(60)

      assert [device] = Fleet.snapshot()
      assert device.status == :stale
      assert device.battery == 77, "the last known reading is still worth showing"
    end
  end

  test "instruct_all reaches simulated devices only" do
    {:ok, 2} = Fleet.start_simulated_fleet(2, tick_ms: 0)
    {:ok, _} = Fleet.attach_real("bench-agv")

    Fleet.instruct_all({:set_battery, 5.0})
    Process.sleep(50)

    snapshot = Fleet.snapshot()
    simulated = Enum.filter(snapshot, &(&1.kind == :simulated))
    real = Enum.find(snapshot, &(&1.kind == :real))

    assert Enum.all?(simulated, &(&1.battery == 5.0))
    assert real.battery == nil, "a real battery cannot be instructed to be flat"
  end

  test "fixed stations expose the clean-rule properties" do
    assert {:ok, 5} = Fleet.start_stations(tick_ms: 0)

    snapshots = Fleet.snapshot()
    assert Enum.map(snapshots, & &1.thing_id) == Enum.sort(Station.known())
    assert Enum.all?(snapshots, &(&1.kind == :station and &1.status == :online))

    snapshots
    |> Enum.each(fn station -> send(Fleet.whereis(station.thing_id), :tick) end)

    Process.sleep(20)
    assert Enum.all?(Fleet.snapshot(), &Map.has_key?(&1, :value))
  end
end
