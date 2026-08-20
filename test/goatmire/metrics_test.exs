defmodule Goatmire.MetricsTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Plug.{Conn, Test}

  alias Goatmire.{Metrics, Metrics.Exporter}

  setup do
    previous_port = Application.get_env(:goatmire, :metrics_port)
    Application.put_env(:goatmire, :metrics_port, 0)

    on_exit(fn ->
      if previous_port do
        Application.put_env(:goatmire, :metrics_port, previous_port)
      else
        Application.delete_env(:goatmire, :metrics_port)
      end
    end)

    :ok
  end

  test "defines the gate, engine, fleet, ExMaude, and VM measurements" do
    names =
      Metrics.metrics()
      |> Enum.map(& &1.name)
      |> MapSet.new()

    assert [:goatmire, :verify, :duration] in names
    assert [:goatmire, :engine, :alerts, :total] in names
    assert [:goatmire, :fleet, :devices] in names
    assert [:ex_maude, :iot, :detect_conflicts, :duration] in names
    assert [:vm, :memory, :total] in names
  end

  test "normalises structured verification scenarios for Prometheus labels" do
    scenario_metrics =
      Metrics.metrics()
      |> Enum.filter(&(:scenario in &1.tags))

    assert scenario_metrics != []

    for metric <- scenario_metrics do
      assert %{scenario: "{:storm, :observe}"} =
               metric.tag_values.(%{status: :conflicts, scenario: {:storm, :observe}})

      assert %{scenario: "unspecified"} =
               metric.tag_values.(%{status: :unverified, scenario: nil})
    end
  end

  test "dispatches the current fleet size as telemetry" do
    handler_id = "metrics-test-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler_id,
        [:goatmire, :fleet],
        fn event, measurements, metadata, pid ->
          send(pid, {:metric, event, measurements, metadata})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    assert :ok = Metrics.dispatch_fleet_size()
    assert_receive {:metric, [:goatmire, :fleet], %{devices: devices}, %{}}, 500
    assert devices == Goatmire.Fleet.count()
  end

  test "starts the reporter and serves Prometheus text" do
    start_supervised!(Metrics)
    :ok = Metrics.dispatch_fleet_size()

    conn = Exporter.call(conn(:get, "/metrics"), [])
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/plain; version=0.0.4"]
    assert conn.resp_body =~ "goatmire_"

    assert Exporter.call(conn(:get, "/"), []).resp_body =~ "scrape /metrics"
    assert Exporter.call(conn(:get, "/missing"), []).status == 404
  end

  test "exporter child spec keeps a stable supervisor id" do
    assert %{id: Exporter} = Exporter.child_spec(port: 0)
  end
end
