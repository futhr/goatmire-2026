defmodule Goatmire.ProtocolAndWarehousePropertyTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Goatmire.Protocol.VDA5050
  alias Goatmire.Warehouse

  @moduletag :property

  property "VDA 5050 state projection preserves bounded device readings" do
    check all(
            serial <- string(:alphanumeric, min_length: 1, max_length: 24),
            battery_tenths <- integer(0..1_000),
            x_hundredths <- integer(0..6_000),
            y_hundredths <- integer(0..4_000),
            mode <- member_of([:idle, :driving, :charging]),
            header_id <- non_negative_integer(),
            max_runs: 150
          ) do
      battery = battery_tenths / 10
      x = x_hundredths / 100
      y = y_hundredths / 100

      message =
        VDA5050.state(
          serial,
          %{battery: battery, position: {x, y}, mode: mode, destination: "dock-7"},
          header_id
        )

      assert {:ok, ^serial, readings} = VDA5050.readings_from_state(message)
      assert {"battery", Float.round(battery, 1)} in readings
      assert {"position", %{"x" => Float.round(x, 2), "y" => Float.round(y, 2)}} in readings
      assert {"mode", Atom.to_string(mode)} in readings
      assert {"destination", "dock-7"} in readings
      assert message["headerId"] == header_id
    end
  end

  property "deterministic home positions stay inside the warehouse" do
    {width, height} = Warehouse.dimensions()

    check all(thing_id <- string(:printable, min_length: 1, max_length: 120), max_runs: 300) do
      {x, y} = Warehouse.home_position(thing_id)

      assert {x, y} == Warehouse.home_position(thing_id)
      assert x >= 0 and x <= width
      assert y >= 0 and y <= height
      assert Warehouse.zone_of({x, y}) in Enum.map(1..9, &"zone-#{&1}")
    end
  end

  property "zone calculation clamps arbitrary finite coordinates to the nine-zone vocabulary" do
    check all(
            x <- integer(-100_000..100_000),
            y <- integer(-100_000..100_000),
            max_runs: 250
          ) do
      assert Warehouse.zone_of({x, y}) in Enum.map(1..9, &"zone-#{&1}")
    end
  end
end
