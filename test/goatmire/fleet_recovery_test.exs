defmodule Goatmire.FleetRecoveryTest do
  use ExUnit.Case, async: false
  alias Goatmire.Fleet

  test "registry replacement recreates configured devices" do
    saved =
      Application.get_all_env(:goatmire)
      |> Keyword.take([:autostart_fleet, :fleet_size, :device_tick_ms])

    on_exit(fn ->
      Enum.each(saved, fn {key, value} -> Application.put_env(:goatmire, key, value) end)
      Fleet.stop_all()
    end)

    Application.put_env(:goatmire, :autostart_fleet, true)
    Application.put_env(:goatmire, :fleet_size, 2)
    Application.put_env(:goatmire, :device_tick_ms, 0)
    registry = Process.whereis(Goatmire.Fleet.Registry)
    Process.exit(registry, :kill)
    await_recovery(registry, 100)
    assert Fleet.count() == 2
  end

  defp await_recovery(_, 0), do: flunk("fleet did not recover")

  defp await_recovery(previous, attempts) do
    recovered =
      Process.whereis(Goatmire.Fleet.Registry) not in [nil, previous] and
        Process.whereis(Goatmire.FleetBootstrap) != nil

    if recovered do
      :ok
    else
      Process.sleep(10)
      await_recovery(previous, attempts - 1)
    end
  end
end
