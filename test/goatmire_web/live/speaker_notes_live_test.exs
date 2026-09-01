defmodule GoatmireWeb.SpeakerNotesLiveTest do
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

  test "notes stay locked without the stage session", %{conn: conn} do
    {:ok, view, html} = live(conn, "/talk/notes")

    assert html =~ "Speaker notes are locked."
    refute html =~ "A bad answer, a good answer"

    render_hook(view, "nav", %{"dir" => "next"})
    assert Clock.snapshot().slide == 1
  end

  test "the configured token unlocks a clean notes URL", %{conn: conn} do
    conn = get(conn, "/talk/notes/unlock/test-speaker-notes")

    assert redirected_to(conn) == "/talk/notes"

    {:ok, _, html} =
      conn
      |> recycle()
      |> live("/talk/notes")

    assert html =~ ~s(id="speaker-notes")
    assert html =~ ~s(id="speaker-controls")
    assert html =~ "Two reasonable rules disagree"
    assert html =~ "A bad answer, a good answer, and no answer are three different things."
    refute html =~ "<img"
  end

  test "the bottom control row is icon-only and touch-labelled", %{conn: conn} do
    {:ok, view, _} = authorized_live(conn)

    buttons =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#speaker-controls button")
      |> Enum.to_list()

    assert length(buttons) == 9

    for button <- buttons do
      assert String.trim(LazyHTML.text(button)) == ""
      assert [_] = LazyHTML.attribute(button, "aria-label")

      svgs =
        button
        |> LazyHTML.query("svg")
        |> Enum.to_list()

      assert [_] = svgs
    end
  end

  test "a wrong token reveals nothing", %{conn: conn} do
    conn = get(conn, "/talk/notes/unlock/wrong-token-value")
    assert response(conn, 404) == "Not found"
  end

  test "tapping a text section moves the shared projector clock", %{conn: conn} do
    {:ok, view, _} = authorized_live(conn)

    view
    |> element("#speaker-note-7")
    |> render_click()

    assert Clock.snapshot().slide == 7
    assert render(view) =~ ~r/id="speaker-note-7"[^>]*class="[^"]*current/
  end

  test "projector navigation moves the current iPad text section", %{conn: conn} do
    {:ok, view, _} = authorized_live(conn)

    Clock.goto(11)

    assert_eventually(fn ->
      render(view) =~ ~r/data-current-slide="11"/ and
        render(view) =~ ~r/id="speaker-note-11"[^>]*class="[^"]*current/
    end)
  end

  test "projector keys and iPad taps stay bidirectionally synchronized", %{conn: conn} do
    {:ok, notes, _} = authorized_live(conn)
    {:ok, projector, _} = live(build_conn(), "/talk")

    render_keydown(projector, "key", %{"key" => "ArrowRight"})

    assert_eventually(fn -> render(notes) =~ ~r/data-current-slide="2"/ end)

    notes
    |> element("#speaker-note-8")
    |> render_click()

    assert_eventually(fn -> render(projector) =~ ~s(id="deck-slide-8") end)
  end

  test "touch controls navigate, switch layout, and zoom the shared stage", %{conn: conn} do
    {:ok, notes, _} = authorized_live(conn)
    {:ok, projector, _} = live(build_conn(), "/talk")

    render_click(element(notes, "#speaker-next"))
    assert %{slide: 2, started?: true} = Clock.snapshot()
    assert_eventually(fn -> render(projector) =~ ~s(id="deck-slide-2") end)

    render_click(element(notes, "#speaker-split"))
    assert Clock.snapshot().panel == :split

    assert_eventually(fn ->
      html = render(projector)
      not (html =~ "presenter-grid deck-full") and not (html =~ "presenter-grid live-full")
    end)

    render_click(element(notes, "#speaker-zoom-in"))
    assert Clock.snapshot().zoom == 1.1
    assert_eventually(fn -> render(projector) =~ ~s(style="zoom: 1.1") end)
  end

  test "blue live actions stay to the right and share progress with keyboard p", %{conn: conn} do
    {:ok, notes, _} = authorized_live(conn)
    {:ok, projector, _} = live(build_conn(), "/talk")

    Clock.goto(13)

    assert_eventually(fn -> render(notes) =~ ~s(id="speaker-play-step-0") end)
    assert render(notes) =~ ~r/speaker-controls-core.*speaker-controls-dynamic/s

    render_keydown(projector, "key", %{"key" => "p"})

    assert_eventually(fn ->
      Clock.snapshot().play_done[13] == 1 and
        render(notes) =~ ~r/id="speaker-play-step-0"[^>]*class="done"/
    end)

    render_click(element(notes, "#speaker-play-step-1"))
    assert Clock.snapshot().play_done[13] == 2
    assert_eventually(fn -> length(Engine.deployed_rules()) == 1 end)
  end

  test "reset confirmation stays inside the icon row", %{conn: conn} do
    {:ok, notes, _} = authorized_live(conn)

    Clock.goto(6)
    render_click(element(notes, "#speaker-ask-reset"))

    html = render(notes)
    assert html =~ ~s(id="speaker-cancel-reset")
    assert html =~ ~s(id="speaker-confirm-reset")
    refute html =~ "speaker-controls-dynamic"

    render_click(element(notes, "#speaker-cancel-reset"))
    assert Clock.snapshot().slide == 6

    render_click(element(notes, "#speaker-ask-reset"))
    render_click(element(notes, "#speaker-confirm-reset"))

    assert %{slide: 1, started?: false, play_done: %{}} = Clock.snapshot()
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
