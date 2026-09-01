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

  test "the projector renders the deck without visual presenter controls", %{conn: conn} do
    {:ok, _, html} = live(conn, "/talk")

    assert html =~ ~s(id="deck-slide-1")
    refute html =~ "presenter-chrome"
    refute html =~ "live-tabs"
    refute html =~ "speaker-controls"
  end

  test "arrow-key navigation advances the deck and starts the clock", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    render_keydown(view, "key", %{"key" => "ArrowRight"})

    assert render(view) =~ ~s(id="deck-slide-2")
    assert Clock.snapshot().started?
  end

  test "a LIVE slide enters deck-only with no panel control", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(13)
    assert_eventually(fn -> render(view) =~ "deck-full" end)
    refute render(view) =~ "live-tabs"

    Clock.reveal()
    assert_eventually(fn -> render(view) =~ ~r/class="presenter live-full"/ end)
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

  test "p steps the shared scripted sequence without rendering a dock", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    Clock.goto(13)
    render_keydown(view, "key", %{"key" => "p"})

    assert_eventually(fn -> length(Engine.deployed_rules()) == 1 end)
    assert Clock.snapshot().play_done[13] == 1
    refute render(view) =~ "live-tabs"
  end

  test "PageUp and PageDown drive the deck — the clicker path", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    render_keydown(view, "key", %{"key" => "PageDown"})
    assert render(view) =~ ~s(id="deck-slide-2")

    render_keydown(view, "key", %{"key" => "PageUp"})
    assert render(view) =~ ~s(id="deck-slide-1")
  end

  test "slide 1 is deck-only: no pane, no pill", %{conn: conn} do
    {:ok, _, html} = live(conn, "/talk")

    assert html =~ "deck-full"
    refute html =~ "live-tabs"
  end

  test "question mark opens keyboard help and escape closes it", %{conn: conn} do
    {:ok, view, _} = live(conn, "/talk")

    render_keydown(view, "key", %{"key" => "?"})

    html = render(view)
    assert html =~ ~s(id="presenter-shortcuts")
    assert html =~ "Next live action"
    assert html =~ "Touch controls live on the private speaker-notes screen"

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

  test "an iPad action evaluates a projector code card", %{conn: conn} do
    {:ok, presenter, _} = live(conn, "/talk")
    {:ok, notes, _} = authorized_live(conn)

    Clock.goto(12)
    Clock.reveal()
    assert_eventually(fn -> render(notes) =~ ~s(id="speaker-run-code") end)

    notes
    |> element("#speaker-run-code")
    |> render_click()

    assert_eventually(fn ->
      render(presenter) =~ "genuinely_low"
    end)
  end

  defp authorized_live(conn) do
    conn
    |> get("/talk/notes/unlock/test-speaker-notes")
    |> recycle()
    |> live("/talk/notes")
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
