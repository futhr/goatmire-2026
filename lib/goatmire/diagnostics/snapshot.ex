defmodule Goatmire.Diagnostics.Snapshot do
  @moduledoc """
  Named windows over `Goatmire.Diagnostics.Sampler`.

  Callers say `:one_minute`, not `60` — the shared vocabulary keeps the
  dashboard, the BeamLens skill callbacks, and the console asking for the
  same bounded evidence.
  """

  alias Goatmire.Diagnostics.Sampler

  @windows %{ten_seconds: 10, one_minute: 60, five_minutes: 300}

  @doc "Reads a named or numeric bounded window from the diagnostic sampler."
  @spec read(10..300 | :ten_seconds | :one_minute | :five_minutes) :: map()
  def read(window \\ :one_minute)

  def read(window) when is_map_key(@windows, window),
    do: Sampler.snapshot(Map.fetch!(@windows, window))

  def read(window) when window in 10..300, do: Sampler.snapshot(window)

  def read(other) do
    raise ArgumentError,
          "diagnostic window must be 10..300 seconds or a named window, got: #{inspect(other)}"
  end
end
