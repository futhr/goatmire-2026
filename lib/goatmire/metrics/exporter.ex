defmodule Goatmire.Metrics.Exporter do
  @moduledoc """
  Serves the Prometheus scrape on its own port, via Bandit.

  `telemetry_metrics_prometheus` ships a Cowboy server for this; Bandit is
  already here for Phoenix, so this avoids a second HTTP server and its CVE
  surface. Runs in every node role — a simulator has no Phoenix endpoint but
  still has metrics worth scraping.

      GET /metrics   → text/plain; version=0.0.4
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{request_path: "/metrics"} = conn, _) do
    metrics = TelemetryMetricsPrometheus.Core.scrape(Goatmire.Metrics.reporter_name())

    conn
    |> put_resp_content_type("text/plain; version=0.0.4", nil)
    |> send_resp(200, metrics)
  end

  def call(%Plug.Conn{request_path: "/"} = conn, _) do
    send_resp(conn, 200, "goatmire metrics — scrape /metrics\n")
  end

  def call(conn, _), do: send_resp(conn, 404, "not found\n")

  @doc "Child spec for the Bandit server carrying this plug."
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    port = Keyword.fetch!(opts, :port)

    Supervisor.child_spec(
      {Bandit, plug: __MODULE__, scheme: :http, port: port, startup_log: false},
      id: __MODULE__
    )
  end
end
