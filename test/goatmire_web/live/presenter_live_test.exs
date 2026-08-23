defmodule GoatmireWeb.PresenterLiveTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import Phoenix.{ConnTest, LiveViewTest}

  alias Goatmire.{Engine, StubVerifier}
  alias Goatmire.Talk.Clock

  @endpoint GoatmireWeb.Endpoint

  setup do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    :ok = Engine.undeploy()
    Clock.reset()

    on_exit(fn ->
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
      Clock.reset()
    end)

    %{conn: build_conn()}
  end

  test "renders slide 1, the pane tabs, and the chrome", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/talk")

    assert html =~ "1 / 25"
    assert html =~ "Warehouse"
    assert html =~ "Metrics"
    assert html =~ "presenter-chrome"
  end

  test "chrome navigation advances the deck and starts the clock", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    view |> element("button[phx-value-dir=next]") |> render_click()

    assert render(view) =~ "2 / 25"
    assert Clock.snapshot().started?
  end

  test "a LIVE slide expands the live panel and selects its pane", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(16)

    assert_eventually(fn ->
      html = render(view)
      html =~ "live-full" and html =~ "aria-selected=\"true\""
    end)
  end

  test "a Maude slide shows its code card in the right panel", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(13)

    assert_eventually(fn -> render(view) =~ "code-card" end)
  end

  test "the play dock steps the scripted sequence with labeled buttons", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(16)
    assert_eventually(fn -> render(view) =~ "Deploy rule A" end)

    view |> element("#play-next") |> render_click()

    html = render(view)
    assert html =~ ~r/class="done"[^>]*>.*?Deploy rule A/s
    assert html =~ "Load rule B"
  end

  test "PageUp and PageDown drive the deck — the clicker path", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    render_keydown(view, "key", %{"key" => "PageDown"})
    assert render(view) =~ "2 / 25"

    render_keydown(view, "key", %{"key" => "PageUp"})
    assert render(view) =~ "1 / 25"
  end

  test "slide 1 is deck-only: no pane, no pill", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/talk")

    assert html =~ "deck-full"
    refute html =~ "live-tabs"
  end

  test "the Code icon exists only on slides with a code card", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(13)
    assert_eventually(fn -> render(view) =~ ~s(phx-value-tab="code") end)

    Clock.goto(23)

    assert_eventually(fn ->
      html = render(view)

      not (html =~ ~s(phx-value-tab="code")) and
        html =~ ~s(aria-selected="true" class="active" phx-click="tab" phx-value-tab="metrics")
    end)
  end

  test "the visible pane delegates its actions to the dock", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(13)
    assert_eventually(fn -> render(view) =~ "live-tabs" end)

    # the code card contributes its own action
    assert render(view) =~ "run_code"

    view |> element(~s(button[phx-value-tab="rules"])) |> render_click()
    assert render(view) =~ "Deploy rule A"

    view |> element(~s(button[phx-value-step="seed_deployed"])) |> render_click()

    assert_eventually(fn -> length(Engine.deployed_rules()) == 1 end)
  end

  test "reset asks for confirmation in-app before clearing the talk", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    view |> element("button[phx-value-dir=next]") |> render_click()
    assert Clock.snapshot().started?

    refute render(view) =~ "presenter-modal"

    view |> element("button[phx-click=ask_reset]") |> render_click()
    html = render(view)
    assert html =~ "presenter-modal"
    assert html =~ "Reset the talk?"

    view |> element("button[phx-click=cancel_reset]", "Cancel") |> render_click()
    refute render(view) =~ "presenter-modal"
    assert Clock.snapshot().slide == 2

    view |> element("button[phx-click=ask_reset]") |> render_click()
    view |> element("#confirm-reset") |> render_click()

    refute render(view) =~ "presenter-modal"
    assert %{slide: 1, started?: false} = Clock.snapshot()
  end

  test "escape dismisses the reset dialog without resetting", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(6)
    view |> element("button[phx-click=ask_reset]") |> render_click()
    assert render(view) =~ "presenter-modal"

    render_keydown(view, "key", %{"key" => "Escape"})

    refute render(view) =~ "presenter-modal"
    assert Clock.snapshot().slide == 6
  end

  test "the dialog owns the keyboard while it is open", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(6)
    view |> element("button[phx-click=ask_reset]") |> render_click()

    render_keydown(view, "key", %{"key" => "ArrowRight"})

    assert Clock.snapshot().slide == 6
  end

  test "every code card is runnable code, not commentary", %{conn: conn} do
    {:ok, _view, _} = live(conn, "/talk")

    for slide <- 1..25, example = GoatmireWeb.Presenter.CodeExamples.example(slide) do
      refute example.code =~ ~r/^\s*defp?\s/m,
             "slide #{slide} quotes a definition instead of a call"

      assert {:ok, _ast} = Code.string_to_quoted(example.code),
             "slide #{slide} does not parse"

      code = String.trim(example.code)

      refute code |> String.split("\n") |> Enum.all?(&String.starts_with?(String.trim(&1), "#")),
             "slide #{slide} is only comments"
    end
  end

  test "a code card evaluates and renders its result", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(14)
    assert_eventually(fn -> render(view) =~ "run-code-card" end)

    view |> element("#run-code-card") |> render_click()

    assert_eventually(fn ->
      html = render(view)
      html =~ "genuinely_low" and html =~ "Reevaluate"
    end)
  end

  test "panel override buttons switch the grid class", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    view |> element("button[phx-value-panel=deck_full]") |> render_click()
    assert render(view) =~ "deck-full"

    view |> element("button[phx-value-panel=split]") |> render_click()
    refute render(view) =~ "deck-full"
  end

  defp assert_eventually(fun, timeout_ms \\ 3_000) do
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
