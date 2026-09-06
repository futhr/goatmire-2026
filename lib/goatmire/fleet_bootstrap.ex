defmodule Goatmire.FleetBootstrap do
  @moduledoc "Restores the configured devices each time the fleet supervisor starts."
  use GenServer
  alias Goatmire.{Config, Fleet}

  @doc "Starts the device bootstrap after the registry and dynamic supervisor."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_) do
    Enum.each(Config.real_devices(), fn opts ->
      ensure_started(Fleet.attach_real(Keyword.fetch!(opts, :thing_id), opts))
    end)

    Enum.each(Config.modbus_sensors(), fn opts ->
      ensure_started(Fleet.attach_modbus_sensor(Keyword.fetch!(opts, :thing_id), opts))
    end)

    if Config.autostart_fleet?() do
      {:ok, _} =
        Fleet.start_simulated_fleet(Config.fleet_size(),
          offset: Config.fleet_offset(),
          tick_ms: Config.device_tick_ms()
        )
    end

    {:ok, %{}}
  end

  defp ensure_started({:ok, _}), do: :ok
  defp ensure_started({:error, {:already_started, _}}), do: :ok
  defp ensure_started(other), do: raise("device startup failed: #{inspect(other)}")
end
