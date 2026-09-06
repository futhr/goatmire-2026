defmodule Goatmire.Talk.Supervisor do
  @moduledoc """
  Presenter state and commands are supervised separately from the demo domain.
  A demo-branch restart preserves them; exhausting the root budget does not.
  """

  use Supervisor

  @doc "Starts the talk-critical supervision branch."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Supervisor.init([Goatmire.Talk.Store, Goatmire.Talk.Clock, Goatmire.Talk.Actions],
      strategy: :rest_for_one,
      max_restarts: 20,
      max_seconds: 10
    )
  end
end
