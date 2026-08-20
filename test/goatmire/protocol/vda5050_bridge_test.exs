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
