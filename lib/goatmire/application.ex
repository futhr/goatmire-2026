defmodule Goatmire.Application do
  @moduledoc false
  use Application

  alias Goatmire.Config

  @impl true
  def start(_, _) do
    # Two branches under the root: talk-critical (clock, endpoint) and the
    # demo domain. A demo crash-loop burns Goatmire.Demo.Supervisor's restart
    # budget before consuming the root restart budget.
    children =
      [
        {Phoenix.PubSub, name: Goatmire.PubSub},
        {Task.Supervisor, name: Goatmire.TaskSupervisor},
        {Finch, name: Goatmire.Finch}
      ] ++ talk_children() ++ web_children() ++ [Goatmire.Demo.Supervisor]

    # Burst-tolerant: a demo-branch meltdown restarts as fast as it can fail
    # without exhausting the root, while a permanent crash-loop still stops
    # the node rather than looping forever.
    opts = [strategy: :rest_for_one, name: Goatmire.Supervisor, max_restarts: 20, max_seconds: 5]

    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _, removed) do
    GoatmireWeb.Endpoint.config_change(changed, removed)
    :ok
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
