defmodule GoatmireWeb.ResponsiveLayoutTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Phoenix.ConnTest

  @endpoint GoatmireWeb.Endpoint

  test "root layout declares viewport, keyboard navigation, and responsive breakpoints" do
    conn = get(build_conn(), "/warehouse")
    html = html_response(conn, 200)

    assert html =~ ~s(name="viewport")
    assert html =~ ~s(class="skip-link")
    assert html =~ ~s(id="main-content")
    assert html =~ "@media (max-width: 900px)"
    assert html =~ "@media (max-width: 680px)"
    assert html =~ "min-height: 44px"
    assert html =~ "grid-template-columns: repeat(2, minmax(0, 1fr))"
  end
end
