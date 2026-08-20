defmodule Goatmire.WarehouseTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Goatmire.Warehouse

  test "the hall is 60 by 40 metres" do
    assert Warehouse.dimensions() == {60, 40}
  end

  test "every dock has a position inside the hall" do
    {width, height} = Warehouse.dimensions()

    assert map_size(Warehouse.docks()) == Warehouse.dock_count()

    Enum.each(Warehouse.docks(), fn {id, {x, y}} ->
      assert x >= 0 and x <= width, "#{id} sits outside the hall on x"
      assert y >= 0 and y <= height, "#{id} sits outside the hall on y"
    end)
  end

  test "dock_position/1 accepts both an id string and an ordinal" do
    assert Warehouse.dock_position("dock-3") == Warehouse.dock_position(3)
    assert Warehouse.dock_position("dock-999") == nil
    assert Warehouse.dock_position("not-a-dock") == nil
  end

  describe "zone_of/1" do
    test "corners land in the expected cells" do
      assert Warehouse.zone_of({0, 0}) == "zone-1"
      assert Warehouse.zone_of({59, 0}) == "zone-3"
      assert Warehouse.zone_of({0, 39}) == "zone-7"
      assert Warehouse.zone_of({59, 39}) == "zone-9"
    end

    test "positions on or beyond the boundary stay inside the grid" do
      assert Warehouse.zone_of({60, 40}) == "zone-9"
      assert Warehouse.zone_of({1000, 1000}) == "zone-9"
    end
  end

  test "docks_in_zone/1 returns a sorted list and never invents docks" do
    all =
      Warehouse.docks()
      |> Map.keys()
      |> MapSet.new()

    found =
      1..9
      |> Enum.flat_map(&Warehouse.docks_in_zone("zone-#{&1}"))
      |> MapSet.new()

    assert MapSet.equal?(found, all), "every dock must fall in exactly one zone"
  end

  test "home_position/1 is deterministic and inside the hall" do
    {width, height} = Warehouse.dimensions()

    assert Warehouse.home_position("agv-42") == Warehouse.home_position("agv-42")
    refute Warehouse.home_position("agv-42") == Warehouse.home_position("agv-43")

    Enum.each(1..200, fn n ->
      {x, y} = Warehouse.home_position("agv-#{n}")
      assert x > 0 and x < width
      assert y > 0 and y < height
    end)
  end
end
