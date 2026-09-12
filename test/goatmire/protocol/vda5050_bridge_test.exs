defmodule Goatmire.Protocol.VDA5050.BridgeTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Goatmire.Protocol.VDA5050
  alias Goatmire.Protocol.VDA5050.Bridge
  alias Goatmire.Transport
  alias Goatmire.Transport.Local

  setup do
    start_supervised!({Bridge, deadline_ms: 0})
    :ok
  end

  test "preserves online, offline, and connection-broken states" do
    publish_connection("agv-1", :online)
    assert_eventually(fn -> Bridge.vehicles()["agv-1"] == :online end)

    publish_connection("agv-1", :offline)
    assert_eventually(fn -> Bridge.vehicles()["agv-1"] == :offline end)

    publish_connection("agv-1", :connection_broken)
    assert_eventually(fn -> Bridge.vehicles()["agv-1"] == :connection_broken end)
  end

  test "rejects mismatched and malformed identities before changing state or republishing" do
    :ok = Local.subscribe(Transport.telemetry_topic("agv-7"))
    connection = VDA5050.connection("agv-7", :online)
    state = VDA5050.state("agv-7", %{battery: 44.0})
    bridge = Process.whereis(Bridge)

    for {kind, payload} <- [{:connection, connection}, {:state, state}] do
      send(bridge, {:goatmire_publish, VDA5050.topic("other", kind), payload})

      for serial <- [%{}, [], nil, "", "a/b", <<255>>] do
        send(
          bridge,
          {:goatmire_publish, VDA5050.topic("agv-7", kind),
           Map.put(payload, "serialNumber", serial)}
        )
      end
    end

    send(
      bridge,
      {:goatmire_publish, VDA5050.topic("agv-7", :connection),
       Map.put(connection, "connectionState", "UNKNOWN")}
    )

    assert Bridge.vehicles() == %{}
    assert Process.whereis(Bridge) == bridge
    refute_receive {:goatmire_publish, "goatmire/things/agv-7/telemetry", _}
  end

  test "turns VDA state into the engine telemetry vocabulary" do
    :ok = Local.subscribe(Transport.telemetry_topic("agv-7"))

    state =
      VDA5050.state("agv-7", %{
        position: {2.0, 3.0},
        battery: 44.0,
        mode: :driving,
        destination: "dock-2"
      })

    :ok = Transport.impl().publish(VDA5050.topic("agv-7", :state), state)

    readings = collect_readings(4)
    assert %{"battery" => 44.0, "destination" => "dock-2", "mode" => "driving"} = readings
    assert Bridge.vehicles()["agv-7"] == :online
  end

  test "sends incrementing VDA order headers" do
    :ok = Local.subscribe(VDA5050.topic("agv-3", :order))

    assert :ok = Bridge.send_order("agv-3", "dock-7", {30.0, 38.0})
    first = receive_payload()
    assert first["headerId"] == 0
    assert hd(first["nodes"])["nodeId"] == "dock-7"

    assert :ok = Bridge.send_order("agv-3", "dock-8", {10.0, 12.0})
    assert receive_payload()["headerId"] == 1
  end

  test "an unbuildable order is refused in the caller, keeping vehicle state" do
    publish_connection("agv-5", :online)
    assert_eventually(fn -> Bridge.vehicles()["agv-5"] == :online end)
    bridge = Process.whereis(Bridge)

    for {serial, node_id, position} <- [
          {"agv-5", "dock-7", nil},
          {"agv-5", "dock-7", {1.0, "y"}},
          {"agv-5", "", {1.0, 2.0}},
          {"agv-5", nil, {1.0, 2.0}},
          {"a/b", "dock-7", {1.0, 2.0}},
          {"", "dock-7", {1.0, 2.0}}
        ] do
      assert {:error, :invalid_order} = Bridge.send_order(serial, node_id, position)
    end

    assert Process.whereis(Bridge) == bridge
    assert Bridge.vehicles()["agv-5"] == :online
  end

  test "the tracked vehicle count is bounded" do
    bridge = Process.whereis(Bridge)
    limit = 4_096

    for n <- 1..(limit + 50) do
      send(
        bridge,
        {:goatmire_publish, VDA5050.topic("veh-#{n}", :connection),
         VDA5050.connection("veh-#{n}", :online)}
      )
    end

    assert_eventually(fn -> map_size(Bridge.vehicles()) == limit end, 200)
    assert Process.whereis(Bridge) == bridge

    # A vehicle already tracked still updates after the bound is reached.
    [tracked | _] = Map.keys(Bridge.vehicles())
    publish_connection(tracked, :offline)
    assert_eventually(fn -> Bridge.vehicles()[tracked] == :offline end)
  end

  test "marks a silent online vehicle connection-broken" do
    publish_connection("agv-4", :online)
    assert_eventually(fn -> Bridge.vehicles()["agv-4"] == :online end)

    Process.sleep(2)
    send(Bridge, :sweep)

    assert_eventually(fn -> Bridge.vehicles()["agv-4"] == :connection_broken end)
  end

  defp publish_connection(serial, state) do
    Transport.impl().publish(
      VDA5050.topic(serial, :connection),
      VDA5050.connection(serial, state)
    )
  end

  defp receive_payload do
    receive do
      {:goatmire_publish, _, _} = message ->
        {:ok, _, payload} = Local.accept(message)
        payload
    after
      500 -> flunk("expected a VDA 5050 order")
    end
  end

  defp collect_readings(count, acc \\ %{})
  defp collect_readings(0, acc), do: acc

  defp collect_readings(count, acc) do
    receive do
      {:goatmire_publish, _, _} = message ->
        case Local.accept(message) do
          {:ok, _, %{"property" => property, "value" => value}} ->
            collect_readings(count - 1, Map.put(acc, property, value))

          :ignore ->
            collect_readings(count, acc)
        end
    after
      500 -> flunk("expected #{count} more translated readings")
    end
  end

  defp assert_eventually(fun, attempts \\ 20)
  defp assert_eventually(fun, 0), do: assert(fun.())

  defp assert_eventually(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end
end
