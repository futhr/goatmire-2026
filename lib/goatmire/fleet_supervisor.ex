defmodule Goatmire.FleetSupervisor do
  @moduledoc "Restarts registered devices and their bootstrap when the registry is replaced."
  use Supervisor

  @doc "Starts the fleet dependency tree."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_) do
    Supervisor.init(Goatmire.Fleet.children() ++ [Goatmire.FleetBootstrap],
      strategy: :rest_for_one
    )
  end
end
