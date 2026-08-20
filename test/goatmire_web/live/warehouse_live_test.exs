defmodule GoatmireWeb.WarehouseLiveTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Phoenix.{ConnTest, LiveViewTest}

  alias Goatmire.{Engine, Fleet, Transport}

  @endpoint GoatmireWeb.Endpoint

  setup do
    Fleet.stop_all()
    :ok = Engine.undeploy()
    :ok = Engine.reset()
    on_exit(&Fleet.stop_all/0)
    %{conn: build_conn()}
  end

  test "renders the floor and the counters", %{conn: conn} do
    {:ok, _, html} = live(conn, "/warehouse")

    assert html =~ "Warehouse floor"
    assert html =~ "events ingested"
    assert html =~ "alerts"
    assert html =~ "zone-7"
    assert html =~ ~s(id="warehouse-dashboard")
    assert html =~ ~s(id="fleet-size")
    assert html =~ ~s(max="300")
  end

  test "bounds complete numeric input and rejects partial numbers", %{conn: conn} do
    {:ok, live, _} = live(conn, "/warehouse")

    live
    |> form("#storm-configuration", %{"fleet_size" => "999999", "duration" => "30"})
    |> render_change()

    assert has_element?(live, "#fleet-size[value=\"6000\"]")

    live
    |> form("#storm-configuration", %{"fleet_size" => "6000", "duration" => "999999"})
    |> render_change()

    assert has_element?(live, "#storm-duration[value=\"300\"]")

    live
    |> form("#storm-configuration", %{"fleet_size" => "42devices", "duration" => "300"})
    |> render_change()

    assert has_element?(live, "#fleet-size[value=\"6000\"]")

    live
    |> form("#storm-configuration", %{"fleet_size" => "6000", "duration" => "0"})
    |> render_change()

    assert has_element?(live, "#storm-duration[value=\"1\"]")
  end

  test "a forged storm mode is visible and does not crash the LiveView", %{conn: conn} do
    {:ok, live, _} = live(conn, "/warehouse")

    html = render_click(live, "storm", %{"mode" => "turbo"})

    assert html =~ "Unknown storm mode"
    assert Process.alive?(live.pid)
    assert Fleet.count() == 0
  end

  test "a duplicate storm event is ignored while a run is active", %{conn: conn} do
    {:ok, live, _} = live(conn, "/warehouse")
    send(live.pid, {:storm_started, %{}})
    _ = render(live)

    _ = render_click(live, "storm", %{"mode" => "observe"})
    Process.sleep(30)

    assert Fleet.count() == 0
    assert has_element?(live, "#run-observe[disabled]")
  end

  test "a background storm failure unlocks controls and explains the retry", %{conn: conn} do
    {:ok, live, _} = live(conn, "/warehouse")
    send(live.pid, {:storm_started, %{}})
    _ = render(live)
    send(live.pid, {:storm_failed, "Storm could not complete. Reset and retry."})

    html = render(live)

    assert html =~ "Storm could not complete"
    assert has_element?(live, "#run-observe:not([disabled])")
  end

  test "draws a dot for every local device", %{conn: conn} do
    {:ok, 4} = Fleet.start_simulated_fleet(4, tick_ms: 0)

    {:ok, live, _} = live(conn, "/warehouse")
    html = render(live)

    assert html =~ "agv-1"
    assert html =~ "agv-4"
  end

  test "bounds the floor rendering while reporting the complete fleet", %{conn: conn} do
    {:ok, 520} = Fleet.start_simulated_fleet(520, tick_ms: 0)

    {:ok, live, _} = live(conn, "/warehouse")
    html = render(live)

    assert html =~ "520 Thing(s) tracked"
    assert html =~ "Showing 500 of 520 devices"
    assert length(Regex.scan(~r/<circle\b/, html)) == 500
  end

  @tag :stress
  @tag timeout: 120_000
  test "a 6000-device fleet keeps the LiveView payload bounded", %{conn: conn} do
    {:ok, 6_000} = Fleet.start_simulated_fleet(6_000, tick_ms: 0)

    {:ok, live, _} = live(conn, "/warehouse")
    html = render(live)

    assert html =~ "6000 Thing(s) tracked"
    assert html =~ "Showing 500 of 6000 devices"
    assert length(Regex.scan(~r/<circle\b/, html)) == 500
    assert byte_size(html) < 500_000
  end

  test "counters reflect ingested telemetry", %{conn: conn} do
    {:ok, live, _} = live(conn, "/warehouse")

    assert Engine.status().counters.events == 0

    Transport.publish_telemetry("agv-42", "battery", 44)
    Process.sleep(80)

    send(live.pid, :refresh)
    _ = render(live)

    # Assert against the engine rather than against rendered markup: the
    # counter is the fact, the markup is one rendering of it.
    assert Engine.status().counters.events >= 1
    assert Engine.status().things_seen >= 1
  end

  test "draws Things observed across the transport boundary", %{conn: conn} do
    {:ok, live, _} = live(conn, "/warehouse")

    Transport.publish_telemetry("remote-agv-42", "position", %{"x" => 12.0, "y" => 8.0})
    Transport.publish_telemetry("remote-agv-42", "battery", 44)
    Process.sleep(80)

    send(live.pid, :refresh)
    html = render(live)

    assert html =~ "1 Thing(s) tracked"
    assert html =~ "remote-agv-42 · observed · battery 44"
  end
end
