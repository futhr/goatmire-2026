defmodule GoatmireWeb.PresenterLiveTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import Phoenix.{ConnTest, LiveViewTest}

  alias Goatmire.{Engine, StubVerifier}
  alias Goatmire.Talk.Clock
  alias GoatmireWeb.Presenter.CodeExamples

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
    {:ok, _, html} = live(conn, "/talk")

    assert html =~ "1 / 18"
    assert html =~ "Warehouse"
    assert html =~ "Metrics"
    assert html =~ "presenter-chrome"
  end

  test "chrome navigation advances the deck and starts the clock", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    render_click(element(view, "button[phx-value-dir=next]"))

    assert render(view) =~ "2 / 18"
    assert Clock.snapshot().started?
  end

  test "a LIVE slide enters deck-only with no panel control", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(13)
    assert_eventually(fn -> render(view) =~ "deck-full" end)
    refute render(view) =~ "live-tabs"

    Clock.reveal()

    assert_eventually(fn ->
      html = render(view)
      html =~ ~s(phx-value-tab="rules") and not (html =~ ~s(phx-value-tab="metrics"))
    end)
  end

  test "the bracket key reveals the slide's configured layout", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(13)
    assert_eventually(fn -> render(view) =~ "deck-full" end)

    render_keydown(view, "key", %{"key" => "]"})

    assert_eventually(fn -> render(view) =~ "live-full" end)
  end

  test "a Maude slide shows its code card in the right panel", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(11)

    assert_eventually(fn -> render(view) =~ "code-card" end)
  end

  test "the play dock steps the scripted sequence with labeled buttons", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(13)
    Clock.reveal()
    assert_eventually(fn -> render(view) =~ "Deploy rule A" end)

    view
    |> element("#play-next")
    |> render_click()

    html = render(view)
    assert html =~ ~r/class="done"[^>]*>.*?Deploy rule A/s
    assert html =~ "Load rule B"
  end

  test "PageUp and PageDown drive the deck — the clicker path", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    render_keydown(view, "key", %{"key" => "PageDown"})
    assert render(view) =~ "2 / 18"

    render_keydown(view, "key", %{"key" => "PageUp"})
    assert render(view) =~ "1 / 18"
  end

  test "slide 1 is deck-only: no pane, no pill", %{conn: conn} do
    {:ok, _, html} = live(conn, "/talk")

    assert html =~ "deck-full"
    refute html =~ "live-tabs"
  end

  test "the play button exists only on slides with a code card", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(11)
    Clock.reveal()
    assert_eventually(fn -> render(view) =~ "run-code-dock" end)

    Clock.goto(18)
    Clock.reveal()

    assert_eventually(fn ->
      html = render(view)
      not (html =~ "run-code-dock") and html =~ ~s(phx-value-tab="metrics")
    end)
  end

  test "the slide's own pane delegates its actions to the dock", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    # a code slide offers the play button and no pane actions
    Clock.goto(11)
    Clock.reveal()
    assert_eventually(fn -> render(view) =~ "run-code-dock" end)
    refute render(view) =~ "pane_action"

    # a rules slide offers the rules actions
    Clock.goto(13)
    Clock.reveal()
    assert_eventually(fn -> render(view) =~ "Deploy rule A" end)

    view
    |> element("#play-next")
    |> render_click()

    assert_eventually(fn -> length(Engine.deployed_rules()) == 1 end)
  end

  test "reset asks for confirmation in-app before clearing the talk", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    render_click(element(view, "button[phx-value-dir=next]"))
    assert Clock.snapshot().started?

    refute render(view) =~ "presenter-modal"

    render_click(element(view, "button[phx-click=ask_reset]"))
    html = render(view)
    assert html =~ "presenter-modal"
    assert html =~ "Reset the talk?"

    render_click(element(view, "button[phx-click=cancel_reset]", "Cancel"))
    refute render(view) =~ "presenter-modal"
    assert Clock.snapshot().slide == 2

    render_click(element(view, "button[phx-click=ask_reset]"))

    view
    |> element("#confirm-reset")
    |> render_click()

    refute render(view) =~ "presenter-modal"
    assert %{slide: 1, started?: false} = Clock.snapshot()
  end

  test "escape dismisses the reset dialog without resetting", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(6)
    render_click(element(view, "button[phx-click=ask_reset]"))
    assert render(view) =~ "presenter-modal"

    render_keydown(view, "key", %{"key" => "Escape"})

    refute render(view) =~ "presenter-modal"
    assert Clock.snapshot().slide == 6
  end

  test "the dialog owns the keyboard while it is open", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(6)
    render_click(element(view, "button[phx-click=ask_reset]"))

    render_keydown(view, "key", %{"key" => "ArrowRight"})

    assert Clock.snapshot().slide == 6
  end

  test "question mark opens keyboard help and escape closes it", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    render_keydown(view, "key", %{"key" => "?"})

    html = render(view)
    assert html =~ ~s(id="presenter-shortcuts")
    assert html =~ "Next live action"
    assert html =~ "Hide / show controls"

    render_keydown(view, "key", %{"key" => "Escape"})
    refute render(view) =~ ~s(id="presenter-shortcuts")
  end

  test "keyboard help owns the keyboard while it is open", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(6)
    render_keydown(view, "key", %{"key" => "?"})
    render_keydown(view, "key", %{"key" => "ArrowRight"})

    assert Clock.snapshot().slide == 6

    render_keydown(view, "key", %{"key" => "?"})
    refute render(view) =~ ~s(id="presenter-shortcuts")
  end

  test "c hides and restores the visual controls", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    render_keydown(view, "key", %{"key" => "c"})
    assert render(view) =~ ~r/id="presenter"[^>]*class="[^"]*controls-hidden/

    render_keydown(view, "key", %{"key" => "c"})
    refute render(view) =~ ~r/id="presenter"[^>]*class="[^"]*controls-hidden/
  end

  test "every code card is runnable code, not commentary", %{conn: conn} do
    {:ok, _, _} = live(conn, "/talk")

    for slide <- 1..18, example = CodeExamples.example(slide) do
      refute example.code =~ ~r/^\s*defp?\s/m,
             "slide #{slide} quotes a definition instead of a call"

      assert {:ok, _} = Code.string_to_quoted(example.code),
             "slide #{slide} does not parse"

      code = String.trim(example.code)

      refute code
             |> String.split("\n")
             |> Enum.all?(&String.starts_with?(String.trim(&1), "#")),
             "slide #{slide} is only comments"
    end
  end

  test "a code card evaluates and renders its result", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(12)
    Clock.reveal()
    assert_eventually(fn -> render(view) =~ "run-code-card" end)

    view
    |> element("#run-code-dock")
    |> render_click()

    assert_eventually(fn ->
      html = render(view)
      html =~ "genuinely_low" and html =~ "Reevaluate"
    end)
  end

  test "panel override buttons switch the grid class", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    render_click(element(view, "button[phx-value-panel=deck_full]"))
    assert render(view) =~ "deck-full"

    render_click(element(view, "button[phx-value-panel=split]"))
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
