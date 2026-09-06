defmodule GoatmireWeb.HealthController do
  @moduledoc """
  What the rig can do right now: the interpreter, the transport, the fleet, and
  the engine as four separate facts, since they fail independently.
  """
  use GoatmireWeb, :controller

  alias Goatmire.Health

  @doc "Returns separate Maude, transport, fleet, and engine readiness facts."
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _) do
    payload = Health.snapshot()

    conn
    |> put_status(if Health.ready?(payload), do: :ok, else: :service_unavailable)
    |> json(payload)
  end
end
