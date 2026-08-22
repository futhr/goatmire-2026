defmodule GoatmireWeb.ResponsiveLayoutTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Phoenix.ConnTest

  @endpoint GoatmireWeb.Endpoint

  test "root layout declares viewport, keyboard navigation, and the stylesheet" do
    conn = get(build_conn(), "/warehouse")
    html = html_response(conn, 200)

    assert html =~ ~s(name="viewport")
    assert html =~ ~s(class="skip-link")
    assert html =~ ~s(id="main-content")
    assert html =~ ~s(rel="stylesheet")
    assert html =~ "/assets/dashboard.css"
  end

  test "the dashboard stylesheet keeps the responsive breakpoints and touch targets" do
    css = File.read!("priv/static/assets/dashboard.css")

    assert css =~ "@media (max-width: 900px)"
    assert css =~ "@media (max-width: 680px)"
    assert css =~ "min-height: 44px"
    assert css =~ "grid-template-columns: repeat(2, minmax(0, 1fr))"
  end
end
