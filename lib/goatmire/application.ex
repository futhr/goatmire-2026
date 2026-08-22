defmodule Goatmire.Application do
  @moduledoc false
  use Application

  alias Goatmire.{Config, Fleet}

  @impl true
  def start(_, _) do
    # Two branches under the root: talk-critical (clock, endpoint) and the
    # demo domain. A demo crash-loop burns Goatmire.Demo.Supervisor's restart
    # budget, never the deck's.
    children =
      [
        {Phoenix.PubSub, name: Goatmire.PubSub},
        {Task.Supervisor, name: Goatmire.TaskSupervisor},
        {Finch, name: Goatmire.Finch}
      ] ++ talk_children() ++ [Goatmire.Demo.Supervisor] ++ web_children()

    # Burst-tolerant: a demo-branch meltdown restarts as fast as it can fail
    # without exhausting the root, while a permanent crash-loop still stops
    # the node rather than looping forever.
    opts = [strategy: :one_for_one, name: Goatmire.Supervisor, max_restarts: 20, max_seconds: 5]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      attach_declared_devices()
      maybe_autostart_fleet()
      {:ok, pid}
    end
  end

  @impl true
  def config_change(changed, _, removed) do
    GoatmireWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp attach_declared_devices do
    Enum.each(Config.real_devices(), fn device_opts ->
      Fleet.attach_real(Keyword.fetch!(device_opts, :thing_id), device_opts)
    end)

    Enum.each(Config.modbus_sensors(), fn sensor_opts ->
      Fleet.attach_modbus_sensor(Keyword.fetch!(sensor_opts, :thing_id), sensor_opts)
    end)
  end

  defp maybe_autostart_fleet do
    if Config.autostart_fleet?() do
      Fleet.start_simulated_fleet(Config.fleet_size(),
        offset: Config.fleet_offset(),
        tick_ms: Config.device_tick_ms()
      )
    end
  end

  defp talk_children do
    case Config.role() do
      :engine -> [Goatmire.Talk.Supervisor]
      _ -> []
    end
  end

  defp web_children do
    case Config.role() do
      :engine -> [GoatmireWeb.Endpoint]
      _ -> []
    end
  end
end
