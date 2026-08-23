defmodule Goatmire.Demo.Supervisor do
  @moduledoc """
  Demo-domain branch: transport, fleet, engine, diagnostics, and metrics.

  Everything that can melt down during a live demo restarts inside this
  branch with its own restart budget, so a crash-looping component exhausts
  this supervisor — never the root — and the endpoint plus presenter clock
  stay up.
  """

  use Supervisor

  alias Goatmire.{Config, Fleet, Transport}

  @doc "Starts the demo-domain supervision branch."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children =
      [Transport.impl()] ++
        Fleet.children() ++
        engine_children() ++
        diagnostics_children() ++
        metrics_children()

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 10)
  end

  defp engine_children do
    case Config.role() do
      :simulator -> []
      _ -> [Goatmire.Engine.Supervisor]
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
end
