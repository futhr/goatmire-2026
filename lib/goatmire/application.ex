defmodule Goatmire.Application do
  @moduledoc false
  use Application

  alias Goatmire.{Config, Fleet, Transport}

  @impl true
  def start(_, _) do
    children =
      [
        {Phoenix.PubSub, name: Goatmire.PubSub},
        {Task.Supervisor, name: Goatmire.TaskSupervisor},
        {Finch, name: Goatmire.Finch},
        Transport.impl()
      ] ++
        Fleet.children() ++
        engine_children() ++
        diagnostics_children() ++
        metrics_children() ++
        web_children()

    opts = [strategy: :one_for_one, name: Goatmire.Supervisor]

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

  defp engine_children do
    case Config.role() do
      :simulator ->
        []

      _ ->
        [ex_maude_child_spec(), Goatmire.Engine] ++ vda5050_children()
    end
  end

  defp vda5050_children do
    if Config.vda5050_enabled?(), do: [Goatmire.Protocol.VDA5050.Bridge], else: []
  end

  defp web_children do
    case Config.role() do
      :engine -> [GoatmireWeb.Endpoint]
      _ -> []
    end
  end

  defp diagnostics_children do
    case Config.role() do
      :engine ->
        client_registry = Config.diagnostics_client_registry()

        [
          Goatmire.Diagnostics.Sampler,
          {Goatmire.Diagnostics.BeamlensSupervisor, client_registry: client_registry},
          {BeamlensWeb, client_registry: client_registry}
        ]

      _ ->
        []
    end
  end

  defp metrics_children do
    if Config.metrics_enabled?(), do: [Goatmire.Metrics], else: []
  end

  # Preload into every worker at start. Otherwise the first reduction broadcasts
  # a load into workers that may be busy, and concurrent verifications race.
  defp preload_maude_templates do
    Application.put_env(:ex_maude, :preload_modules, [
      ExMaude.iot_rules_path(),
      ExMaude.ai_rules_path()
    ])
  end

  defp ex_maude_child_spec do
    preload_maude_templates()

    :erlang.apply(ExMaude.Pool, :child_spec, [[pool_size: 4, pool_max_overflow: 0]])
    |> normalize_child_spec()
  end

  defp normalize_child_spec(%{} = child_spec), do: child_spec

  defp normalize_child_spec({id, start, restart, shutdown, type, modules}) do
    %{id: id, start: start, restart: restart, shutdown: shutdown, type: type, modules: modules}
  end
end
