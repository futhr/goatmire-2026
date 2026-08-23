defmodule Goatmire.Talk.Supervisor do
  @moduledoc """
  Talk-critical branch: the presenter clock must outlive any demo meltdown,
  so it supervises separately from the demo domain.
  """

  use Supervisor

  @doc "Starts the talk-critical supervision branch."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Supervisor.init([Goatmire.Talk.Store, Goatmire.Talk.Clock],
      strategy: :one_for_one,
      max_restarts: 20,
      max_seconds: 10
    )
  end
end
