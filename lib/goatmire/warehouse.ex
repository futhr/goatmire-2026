defmodule Goatmire.Warehouse do
  @moduledoc """
  Floor plan for the simulated fleet and the dashboard.

  A 60 m × 40 m hall in a 3 × 3 zone grid. Docks line the north wall and the
  central aisle; docks 1–4 sit inside Zone-7, the cell the shift-hours rule
  closes. Coordinates are metres from the south-west corner.
  """

  @width 60
  @height 40
  @zone_cols 3
  @zone_rows 3
  @dock_count 24

  @doc "Hall dimensions in metres, `{width, height}`."
  @spec dimensions() :: {pos_integer(), pos_integer()}
  def dimensions, do: {@width, @height}

  @doc "Every dock id mapped to its position."
  @spec docks() :: %{String.t() => {number(), number()}}
  def docks do
    for n <- 1..@dock_count, into: %{} do
      {"dock-#{n}", dock_position(n)}
    end
  end

  @doc "Position of a dock by id, or nil."
  @spec dock_position(String.t() | pos_integer()) :: {number(), number()} | nil
  def dock_position(n) when is_integer(n) and n in 1..@dock_count do
    # Docks 1–12 line the north wall; 13–24 run down the central aisle, which
    # is what pushes the majority of them into the middle column of zones.
    if n <= 12 do
      {n * (@width / 13), @height - 2}
    else
      {@width / 2, (n - 12) * (@height / 13)}
    end
  end

  def dock_position("dock-" <> n) do
    case Integer.parse(n) do
      {number, ""} -> dock_position(number)
      _ -> nil
    end
  end

  def dock_position(_), do: nil

  @doc "How many docks the hall has."
  @spec dock_count() :: pos_integer()
  def dock_count, do: @dock_count

  @doc """
  The zone containing a position, as `"zone-N"` with N in 1..9.

  Numbered left-to-right, bottom-to-top, so Zone-7 is the north-west cell and
  Zone-8 the north-centre cell at the top of the aisle.
  """
  @spec zone_of({number(), number()}) :: String.t()
  def zone_of({x, y}) do
    col = clamp(div_floor(x, @width / @zone_cols), 0, @zone_cols - 1)
    row = clamp(div_floor(y, @height / @zone_rows), 0, @zone_rows - 1)
    "zone-#{row * @zone_cols + col + 1}"
  end

  @doc "Every dock that falls inside the given zone."
  @spec docks_in_zone(String.t()) :: [String.t()]
  def docks_in_zone(zone) do
    docks()
    |> Enum.filter(fn {_, position} -> zone_of(position) == zone end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  @doc """
  A deterministic starting position for a device, spread across the hall.

  Derived from the `thing_id` so a restarted device reappears where it was and
  a screenshot from one rehearsal matches the next.
  """
  @spec home_position(String.t()) :: {number(), number()}
  def home_position(thing_id) do
    hash = :erlang.phash2(thing_id, 10_000)
    x = rem(hash, @width - 4) + 2
    y = rem(div(hash, @width), @height - 4) + 2
    {x * 1.0, y * 1.0}
  end

  defp div_floor(value, size), do: trunc(:math.floor(value / size))
  defp clamp(value, minimum, maximum), do: min(max(value, minimum), maximum)
end
