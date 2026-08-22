defmodule GoatmireWeb.MetricsLiveTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import Phoenix.{ConnTest, LiveViewTest}

  @endpoint GoatmireWeb.Endpoint

  setup do
    %{conn: build_conn()}
  end

  test "renders the tiles with server-rendered sparklines", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/metrics")

    assert html =~ "Alerts / s"
    assert html =~ "Maude pool in use"
    assert html =~ "sparkline"
    assert html =~ "<svg"
  end

  test "the window toggle switches the sampled range", %{conn: conn} do
    {:ok, view, _} = live(conn, "/metrics")

    view |> element(~s(button[phx-value-seconds="60"])) |> render_click()

    assert render(view) =~ "last 60 s"
  end

  test "the summary table stays open across refresh ticks", %{conn: conn} do
    {:ok, view, _} = live(conn, "/metrics")

    view |> element("button", "Window summary as a table") |> render_click()
    assert render(view) =~ "Hide summary table"

    send(view.pid, :refresh)

    assert render(view) =~ "Hide summary table"
    assert render(view) =~ "memory MB"
  end
end
