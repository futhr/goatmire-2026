defmodule GoatmireWeb.NotebookLiveTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import Phoenix.{ConnTest, LiveViewTest}

  @endpoint GoatmireWeb.Endpoint

  setup do
    %{conn: build_conn()}
  end

  test "renders the notebook cells with evaluate buttons", %{conn: conn} do
    {:ok, _, html} = live(conn, "/notebook")

    assert html =~ "Scenario 5"
    assert html =~ "Evaluate"
    assert html =~ "nb-cell"
    assert html =~ "run-cell-"
    assert html =~ "setup — a no-op"
    refute html =~ "<h1>Scenario 5 — The model, by hand</h1>\n<h1>"
  end

  test "evaluating a cell renders its output below", %{conn: conn} do
    {:ok, view, _} = live(conn, "/notebook")

    cell =
      "05_agent_policy_proof"
      |> Goatmire.Notebook.cells()
      |> Enum.find(&(&1.type == :code and not &1.setup?))

    view
    |> element("#run-cell-#{cell.index}")
    |> render_click()

    assert_eventually(fn ->
      html = render(view)
      html =~ "nb-output" and html =~ "Reevaluate"
    end)
  end

  test "switching notebooks reloads the cells", %{conn: conn} do
    {:ok, view, _} = live(conn, "/notebook")

    render_click(element(view, ~s|button[phx-value-slug="01_iot_state_conflict"]|))

    assert render(view) =~ "Scenario 1"
  end

  test "a scripted step runs the next unevaluated cell", %{conn: conn} do
    {:ok, view, _} = live(conn, "/notebook")

    refute render(view) =~ "nb-output"

    Goatmire.Talk.play(:notebook, :run_next)

    assert_eventually(fn -> render(view) =~ "nb-output" end)
  end

  defp assert_eventually(fun, timeout_ms \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    eventually(fun, deadline)
  end

  defp eventually(fun, deadline) do
    cond do
      fun.() ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        assert fun.()

      true ->
        Process.sleep(25)
        eventually(fun, deadline)
    end
  end
end
