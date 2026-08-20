defmodule Goatmire.Protocol.VDA5050 do
  @moduledoc """
  VDA 5050 — the AGV/master-control interface. Runs over MQTT, so this is a
  message and topic shape rather than a new stack.

      <interface>/<majorVersion>/<manufacturer>/<serialNumber>/<topic>
      uagv/v2/goatmire/agv-42/state

  Connection state is three-valued: `ONLINE`, `OFFLINE` (announced before
  leaving), and `CONNECTIONBROKEN` — delivered by the broker as the vehicle's
  MQTT Last Will, registered at connect time so it can be published after the
  vehicle can no longer publish anything.

  Implements the subset the demo exercises: header, `agvPosition`,
  `batteryState`, `driving`, `operatingMode`, `safetyState`, connection, and
  single-node orders. Not a certified implementation — no node/edge/action
  state machine, no conformance evidence.
  """

  @interface "uagv"
  @major_version "v2"
  @version "2.0.0"
  @manufacturer "goatmire"

  @type connection_state :: :online | :offline | :connection_broken

  @doc "Interface name, for building topics elsewhere."
  @spec interface() :: String.t()
  def interface, do: @interface

  @doc "Manufacturer segment used for the demo fleet."
  @spec manufacturer() :: String.t()
  def manufacturer, do: @manufacturer

  @doc """
  Builds a VDA 5050 topic.

      iex> Goatmire.Protocol.VDA5050.topic("agv-42", :state)
      "uagv/v2/goatmire/agv-42/state"
  """
  @spec topic(String.t(), atom()) :: String.t()
  def topic(serial_number, kind)
      when kind in [:connection, :state, :order, :instant_actions, :visualization, :factsheet] do
    Enum.join([@interface, @major_version, @manufacturer, serial_number, segment(kind)], "/")
  end

  defp segment(:instant_actions), do: "instantActions"
  defp segment(kind), do: Atom.to_string(kind)

  @doc "Subscription filter matching every AGV's `state` topic."
  @spec state_filter() :: String.t()
  def state_filter, do: "#{@interface}/#{@major_version}/#{@manufacturer}/+/state"

  @doc "Subscription filter matching every AGV's `connection` topic."
  @spec connection_filter() :: String.t()
  def connection_filter, do: "#{@interface}/#{@major_version}/#{@manufacturer}/+/connection"

  @doc """
  The connection message.

  `:connection_broken` is the payload an AGV hands the broker as its Last Will
  at connect time — it is published *by the broker*, after the AGV is already
  gone. Build it with `last_will/2`.
  """
  @spec connection(String.t(), connection_state(), non_neg_integer()) :: map()
  def connection(serial_number, state, header_id \\ 0) do
    serial_number
    |> header(header_id)
    |> Map.put("connectionState", connection_state(state))
  end

  defp connection_state(:online), do: "ONLINE"
  defp connection_state(:offline), do: "OFFLINE"
  defp connection_state(:connection_broken), do: "CONNECTIONBROKEN"

  @doc """
  The Last Will and Testament an AGV registers when it connects.

  Retained and QoS 1 per the standard's intent: master control must find the
  vehicle's last known connection state even if it subscribes after the
  vehicle died. A demo that skips the retain flag looks fine until the moment
  it matters, which is the moment you restart the dashboard.
  """
  @spec last_will(String.t(), non_neg_integer()) :: map()
  def last_will(serial_number, header_id \\ 0) do
    %{
      topic: topic(serial_number, :connection),
      payload: connection(serial_number, :connection_broken, header_id),
      qos: 1,
      retain: true
    }
  end

  @doc """
  The state message.

  Takes the simulated device's own state map and projects it onto the
  standard's field names. Battery is a percentage in `batteryCharge`;
  `operatingMode` is `AUTOMATIC` throughout because nothing in this demo hands
  control to a human at the vehicle.
  """
  @spec state(String.t(), map(), non_neg_integer()) :: map()
  def state(serial_number, device, header_id \\ 0) do
    {x, y} = Map.get(device, :position, {0.0, 0.0})

    serial_number
    |> header(header_id)
    |> Map.merge(%{
      "orderId" => Map.get(device, :order_id, ""),
      "orderUpdateId" => 0,
      "lastNodeId" => Map.get(device, :destination) || "",
      "lastNodeSequenceId" => 0,
      "nodeStates" => [],
      "edgeStates" => [],
      "actionStates" => [],
      "driving" => Map.get(device, :mode) == :driving,
      "paused" => false,
      "newBaseRequest" => false,
      "distanceSinceLastNode" => 0.0,
      "operatingMode" => "AUTOMATIC",
      "agvPosition" => %{
        "x" => round_to(x, 2),
        "y" => round_to(y, 2),
        "theta" => 0.0,
        "mapId" => "goatmire-hall",
        "positionInitialized" => true
      },
      "velocity" => %{"vx" => velocity(device), "vy" => 0.0, "omega" => 0.0},
      "loads" => [],
      "batteryState" => %{
        "batteryCharge" => round_to(Map.get(device, :battery, 0.0), 1),
        "charging" => Map.get(device, :mode) == :charging,
        "reach" => 0
      },
      "errors" => [],
      "information" => [],
      "safetyState" => %{"eStop" => "NONE", "fieldViolation" => false}
    })
  end

  defp velocity(%{mode: :driving} = device), do: Map.get(device, :speed_mps, 0.0)
  defp velocity(_), do: 0.0

  @doc """
  An `order` message carrying a single destination node.

  The demo's rule engine actuates by naming a dock, which in VDA 5050 terms is
  a one-node order. Real orders carry node/edge graphs with actions attached;
  this is the smallest well-formed thing that expresses "go there".
  """
  @spec order(String.t(), String.t(), {number(), number()}, non_neg_integer()) :: map()
  def order(serial_number, node_id, {x, y}, header_id \\ 0) do
    serial_number
    |> header(header_id)
    |> Map.merge(%{
      "orderId" => "goatmire-#{node_id}-#{header_id}",
      "orderUpdateId" => 0,
      "nodes" => [
        %{
          "nodeId" => node_id,
          "sequenceId" => 0,
          "released" => true,
          "nodePosition" => %{
            "x" => round_to(x, 2),
            "y" => round_to(y, 2),
            "mapId" => "goatmire-hall"
          },
          "actions" => []
        }
      ],
      "edges" => []
    })
  end

  @doc """
  Extracts the fields the engine cares about from an inbound `state` message.

  Returns the property readings a VDA 5050-speaking vehicle contributes, in
  the engine's own event vocabulary — so a real AGV and a simulated one reach
  the rule engine as the same thing.
  """
  @spec readings_from_state(map()) :: {:ok, String.t(), [{String.t(), term()}]} | :error
  def readings_from_state(%{"serialNumber" => serial} = message) do
    readings =
      [
        battery_reading(message),
        position_reading(message),
        mode_reading(message),
        node_reading(message)
      ]
      |> Enum.reject(&is_nil/1)

    {:ok, serial, readings}
  end

  def readings_from_state(_), do: :error

  defp battery_reading(%{"batteryState" => %{"batteryCharge" => charge}}),
    do: {"battery", charge}

  defp battery_reading(_), do: nil

  defp position_reading(%{"agvPosition" => %{"x" => x, "y" => y}}),
    do: {"position", %{"x" => x, "y" => y}}

  defp position_reading(_), do: nil

  defp mode_reading(%{"batteryState" => %{"charging" => true}}), do: {"mode", "charging"}
  defp mode_reading(%{"driving" => true}), do: {"mode", "driving"}
  defp mode_reading(%{"driving" => false}), do: {"mode", "idle"}
  defp mode_reading(_), do: nil

  defp node_reading(%{"lastNodeId" => node}) when is_binary(node) and node != "",
    do: {"destination", node}

  defp node_reading(_), do: nil

  # headerId increments per topic per vehicle so master control can detect a
  # gap. The caller owns the counter; this module does not hold state.
  defp header(serial_number, header_id) do
    %{
      "headerId" => header_id,
      "timestamp" => timestamp(),
      "version" => @version,
      "manufacturer" => @manufacturer,
      "serialNumber" => serial_number
    }
  end

  defp timestamp do
    DateTime.utc_now(:millisecond)
    |> DateTime.to_iso8601()
  end

  defp round_to(value, places) when is_number(value), do: Float.round(value * 1.0, places)
  defp round_to(_, _), do: 0.0
end
