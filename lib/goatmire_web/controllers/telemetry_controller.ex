defmodule GoatmireWeb.TelemetryController do
  @moduledoc """
  HTTP ingress for devices that cannot hold an MQTT session. Publishes onto the
  same transport topic a broker-connected device uses.

      curl -X POST http://localhost:4000/api/things/agv-42/telemetry \\
        -H 'content-type: application/json' -d '{"property":"battery","value":18}'
  """
  use GoatmireWeb, :controller

  alias Goatmire.Transport

  @doc "Publishes one validated HTTP reading onto the configured device transport."
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"thing_id" => thing_id, "property" => property, "value" => value}) do
    :ok = Transport.publish_telemetry(thing_id, property, value)
    json(conn, %{status: "accepted", thing_id: thing_id, property: property})
  end

  def create(conn, _) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "expected JSON body with \"property\" and \"value\""})
  end
end
