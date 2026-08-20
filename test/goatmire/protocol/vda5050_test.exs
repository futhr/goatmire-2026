defmodule Goatmire.Protocol.VDA5050Test do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Goatmire.Protocol.VDA5050
  alias Goatmire.Transport.Local

  describe "topics" do
    test "follow the standard's structure" do
      assert VDA5050.topic("agv-42", :state) == "uagv/v2/goatmire/agv-42/state"
      assert VDA5050.topic("agv-42", :order) == "uagv/v2/goatmire/agv-42/order"
      assert VDA5050.topic("agv-42", :connection) == "uagv/v2/goatmire/agv-42/connection"
    end

    test "instantActions keeps its camelCase segment" do
      assert VDA5050.topic("agv-1", :instant_actions) == "uagv/v2/goatmire/agv-1/instantActions"
    end

    test "filters match every vehicle at exactly one level" do
      assert VDA5050.state_filter() == "uagv/v2/goatmire/+/state"

      assert Local.topic_match?(
               VDA5050.topic("agv-7", :state),
               VDA5050.state_filter()
             )

      refute Local.topic_match?(
               VDA5050.topic("agv-7", :order),
               VDA5050.state_filter()
             )
    end
  end

  describe "connection message" do
    test "carries all three states distinctly" do
      states =
        for s <- [:online, :offline, :connection_broken],
            do: VDA5050.connection("agv-1", s)["connectionState"]

      assert states == ["ONLINE", "OFFLINE", "CONNECTIONBROKEN"]
      assert length(Enum.uniq(states)) == 3
    end

    test "the last will is retained and QoS 1" do
      will = VDA5050.last_will("agv-1")

      assert will.topic == "uagv/v2/goatmire/agv-1/connection"
      assert will.payload["connectionState"] == "CONNECTIONBROKEN"
      assert will.qos == 1

      # Retained so master control learns the vehicle's last known state even
      # if it subscribes after the vehicle died.
      assert will.retain
    end
  end

  describe "state message" do
    setup do
      device = %{
        position: {12.5, 7.25},
        battery: 18.4,
        mode: :driving,
        destination: "dock-7",
        speed_mps: 1.4
      }

      %{message: VDA5050.state("agv-42", device, 3)}
    end

    test "carries the header the standard requires", %{message: message} do
      assert message["headerId"] == 3
      assert message["version"] == "2.0.0"
      assert message["manufacturer"] == "goatmire"
      assert message["serialNumber"] == "agv-42"
      assert {:ok, _, _} = DateTime.from_iso8601(message["timestamp"])
    end

    test "projects position and battery onto the standard's field names", %{message: message} do
      assert message["agvPosition"]["x"] == 12.5
      assert message["agvPosition"]["y"] == 7.25
      assert message["agvPosition"]["positionInitialized"]
      assert message["batteryState"]["batteryCharge"] == 18.4
      refute message["batteryState"]["charging"]
    end

    test "driving is derived from mode, and velocity follows it", %{message: message} do
      assert message["driving"]
      assert message["velocity"]["vx"] == 1.4
    end

    test "a charging vehicle is not driving" do
      message = VDA5050.state("agv-1", %{mode: :charging, battery: 90.0, position: {1.0, 1.0}})

      assert message["batteryState"]["charging"]
      refute message["driving"]
      assert message["velocity"]["vx"] == 0.0
    end
  end

  describe "readings_from_state/1" do
    test "round-trips a state message into engine readings" do
      device = %{position: {3.0, 4.0}, battery: 55.5, mode: :driving, destination: "dock-2"}
      message = VDA5050.state("agv-9", device)

      assert {:ok, "agv-9", readings} = VDA5050.readings_from_state(message)

      assert {"battery", 55.5} in readings
      assert {"position", %{"x" => 3.0, "y" => 4.0}} in readings
      assert {"mode", "driving"} in readings
      assert {"destination", "dock-2"} in readings
    end

    test "an empty destination is not a reading" do
      message = VDA5050.state("agv-9", %{position: {0.0, 0.0}, battery: 10.0, mode: :idle})
      {:ok, _, readings} = VDA5050.readings_from_state(message)

      refute Enum.any?(readings, &match?({"destination", _}, &1))
    end

    test "a message without a serial number is rejected rather than guessed at" do
      assert :error = VDA5050.readings_from_state(%{"batteryState" => %{"batteryCharge" => 10}})
    end
  end

  describe "order message" do
    test "carries one released node with a position" do
      order = VDA5050.order("agv-3", "dock-7", {30.0, 38.0}, 1)

      assert [node] = order["nodes"]
      assert node["nodeId"] == "dock-7"
      assert node["released"]
      assert node["nodePosition"]["x"] == 30.0
      assert order["edges"] == []
    end
  end
end
