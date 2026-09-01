defmodule GoatmireWeb.SpeakerNotesLiveTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import Phoenix.{ConnTest, LiveViewTest}

  alias Goatmire.Talk.Clock

  @endpoint GoatmireWeb.Endpoint

  setup do
    Clock.reset()
    on_exit(fn -> Clock.reset() end)
    %{conn: build_conn()}
  end

  test "notes stay locked without the stage session", %{conn: conn} do
    {:ok, _, html} = live(conn, "/talk/notes")

    assert html =~ "Speaker notes are locked."
    refute html =~ "A bad answer, a good answer"
  end

  test "the configured token unlocks a clean notes URL", %{conn: conn} do
    conn = get(conn, "/talk/notes/unlock/test-speaker-notes")

    assert redirected_to(conn) == "/talk/notes"

    {:ok, _, html} = conn |> recycle() |> live("/talk/notes")

    assert html =~ ~s(id="speaker-notes")
    assert html =~ "Two reasonable rules disagree"
    assert html =~ "A bad answer, a good answer, and no answer are three different things."
    refute html =~ "<svg"
    refute html =~ "<img"
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

    assert_eventually(fn -> render(projector) =~ "8 / 18" end)
  end

  defp authorized_live(conn) do
    conn
    |> get("/talk/notes/unlock/test-speaker-notes")
    |> recycle()
    |> live("/talk/notes")
  end

  defp assert_eventually(fun, attempts \\ 30)
  defp assert_eventually(fun, 0), do: assert(fun.())

  defp assert_eventually(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end
end
