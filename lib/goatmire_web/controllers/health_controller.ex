defmodule GoatmireWeb.HealthController do
  @moduledoc """
  What the rig can do right now: the interpreter, the transport, the fleet, and
  the engine as four separate facts, since they fail independently.
  """
  use GoatmireWeb, :controller

  alias Goatmire.{Config, Engine, Fleet, Gate}

  @doc "Returns separate Maude, transport, fleet, and engine health facts."
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _) do
    {maude_status, maude_detail} =
      case Gate.health() do
        {:ok, version} -> {"ok", version}
        {:error, reason} -> {"unavailable", inspect(reason)}
      end

    engine = Engine.status()

    payload = %{
      maude: %{status: maude_status, detail: maude_detail},
      transport: inspect(Config.transport()),
      fleet: %{devices: Fleet.count()},
      engine: %{
        deployed_rules: engine.deployed_count,
        withheld_rules: length(engine.withheld),
        things_seen: engine.things_seen,
        counters: engine.counters
      }
    }

    conn
    |> put_status(if maude_status == "ok", do: :ok, else: :service_unavailable)
    |> json(payload)
  end
end
