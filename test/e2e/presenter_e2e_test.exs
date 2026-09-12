defmodule GoatmireWeb.PresenterE2ETest do
  @moduledoc false

  use GoatmireWeb.E2ECase,
    async: false,
    browser_context_opts: [viewport: %{width: 1_280, height: 720}, reduced_motion: :reduce]

  alias Goatmire.{Engine, StubVerifier}
  alias Goatmire.Talk.{Clock, Deck}

  @moduletag :e2e
  @moduletag timeout: 60_000

  setup :reset_presenter

  test "every projected slide keeps its content inside the screen", %{conn: conn} do
    conn = visit(conn, "/talk")

    for {slide, title} <- Deck.titles() do
      Clock.goto(slide)

      conn
      |> assert_has("#deck-slide-#{slide} section[aria-label=\"#{title}\"]")
      |> evaluate(
        """
        (() => {
          const slide = document.querySelector('.deck-slide .slide');
          const box = slide.getBoundingClientRect();
          return [...slide.querySelectorAll('*')].filter(element => {
            const child = element.getBoundingClientRect();
            return child.left < box.left - 1 || child.right > box.right + 1 ||
              child.top < box.top - 1 || child.bottom > box.bottom + 1;
          }).map(element => element.textContent.trim());
        })()
        """,
        fn overflow -> assert overflow == [], "slide #{slide} clips #{inspect(overflow)}" end
      )
    end
  end

  test "the projector stays keyboard-driven and free of visual controls", %{conn: conn} do
    conn
    |> visit("/talk")
    |> assert_has("#presenter")
    |> assert_has("[data-phx-main].phx-connected")
    |> refute_has(".presenter-chrome")
    |> refute_has(".live-tabs")
    |> press("body", "ArrowRight")
    |> assert_has("#deck-slide-2")
    |> press("body", "ArrowLeft")
    |> assert_has("#deck-slide-1")

    assert Clock.snapshot().started?
  end

  test "typing in an embedded form does not advance the deck", %{conn: conn} do
    conn = visit(conn, "/talk")

    # Slide 18 is the diagnostics beat; revealing opens its pane.
    Clock.goto(18)
    Clock.reveal()

    conn
    |> assert_has("#diagnostic-prompt")
    |> type("#diagnostic-prompt", "why")
    |> press("#diagnostic-prompt", " ")
    |> assert_has("#deck-slide-18")

    assert %{slide: 18} = Clock.snapshot()
  end

  defp reset_presenter(_) do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    :ok = Engine.undeploy()
    Clock.reset()

    on_exit(fn ->
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
      Clock.reset()
    end)

    :ok
  end
end

defmodule GoatmireWeb.PresenterControlsE2ETest do
  @moduledoc false

  use GoatmireWeb.E2ECase,
    async: false,
    browser_context_opts: [viewport: %{width: 768, height: 1_024}, has_touch: true]

  alias Goatmire.{Engine, StubVerifier}
  alias Goatmire.Talk.Clock

  @moduletag :e2e
  @moduletag timeout: 60_000

  setup :reset_presenter

  test "the iPad row is touch-sized, icon-only, single-line, and controls the stage", %{
    conn: conn
  } do
    conn =
      conn
      |> visit("/talk/notes/unlock/test-speaker-notes")
      |> assert_has("#speaker-controls")
      |> click("#speaker-next")
      |> assert_has("#speaker-note-2.current")
      |> click("#speaker-live-full")

    assert %{slide: 2, panel: :live_full} = Clock.snapshot()

    Clock.goto(22)

    conn
    |> assert_has(".speaker-controls-dynamic button", count: 7)
    |> evaluate(
      """
      (() => {
        const controls = document.getElementById('speaker-controls');
        const buttons = [...controls.querySelectorAll('button')];
        return {
          rows: new Set(buttons.map(button => Math.round(button.getBoundingClientRect().top))).size,
          minSize: Math.min(...buttons.map(button => button.getBoundingClientRect().width)),
          fits: controls.getBoundingClientRect().left >= 0 &&
            controls.getBoundingClientRect().right <= window.innerWidth,
          text: controls.innerText.trim()
        };
      })()
      """,
      fn layout ->
        assert layout["rows"] == 1
        assert layout["minSize"] >= 44
        assert layout["fits"]
        assert layout["text"] == ""
      end
    )
  end

  defp reset_presenter(_) do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    :ok = Engine.undeploy()
    Clock.reset()

    on_exit(fn ->
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
      Clock.reset()
    end)

    :ok
  end
end

defmodule GoatmireWeb.PresenterScriptE2ETest do
  @moduledoc false

  use GoatmireWeb.E2ECase,
    async: false,
    browser_context_opts: [viewport: %{width: 1_024, height: 1_509}, has_touch: true]

  alias Goatmire.{Engine, StubVerifier}
  alias Goatmire.Talk.{Clock, Deck}

  @moduletag :e2e
  @moduletag timeout: 60_000

  setup :reset_presenter

  test "every current iPad script is pinned at the top and clears the controls", %{conn: conn} do
    conn = visit(conn, "/talk/notes/unlock/test-speaker-notes")

    Enum.each(1..Deck.count(), fn slide ->
      Clock.goto(slide)

      conn
      |> assert_has("#speaker-note-#{slide}.current")
      |> evaluate(
        """
        (() => {
          const current = document.querySelector('.speaker-note.current');
          const controls = document.getElementById('speaker-controls');
          const currentBox = current.getBoundingClientRect();
          const controlsBox = controls.getBoundingClientRect();

          return {
            top: Math.round(currentBox.top),
            bottom: Math.round(currentBox.bottom),
            controlsTop: Math.round(controlsBox.top)
          };
        })()
        """,
        fn layout ->
          assert layout["top"] in 20..28,
                 "slide #{slide} starts at #{layout["top"]}px instead of the top"

          assert layout["bottom"] <= layout["controlsTop"] - 12,
                 "slide #{slide} ends behind the controls"
        end
      )
    end)
  end

  defp reset_presenter(_) do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    :ok = Engine.undeploy()
    Clock.reset()

    on_exit(fn ->
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
      Clock.reset()
    end)

    :ok
  end
end
