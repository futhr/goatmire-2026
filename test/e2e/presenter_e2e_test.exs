defmodule GoatmireWeb.PresenterE2ETest do
  @moduledoc false

  use ExUnit.Case, async: false
  use Wallaby.Feature

  import Wallaby.Query

  alias Goatmire.{Engine, StubVerifier}
  alias Goatmire.Talk.{Clock, Deck}

  @moduletag :e2e
  @moduletag timeout: 60_000

  setup_all do
    {:ok, {_, port}} = Bandit.PhoenixAdapter.server_info(GoatmireWeb.Endpoint, :http)
    Application.put_env(:wallaby, :base_url, "http://127.0.0.1:#{port}")
    {:ok, _} = Application.ensure_all_started(:wallaby)
    :ok
  end

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

    :ok
  end

  feature "the projector stays keyboard-driven and free of visual controls", %{
    session: session
  } do
    session
    |> visit("/talk")
    |> assert_has(css("#presenter"))
    |> refute_has(css(".presenter-chrome"))
    |> refute_has(css(".live-tabs"))
    |> send_keys([:right_arrow])
    |> assert_has(css("#deck-slide-2"))
    |> send_keys([:left_arrow])
    |> assert_has(css("#deck-slide-1"))

    assert Clock.snapshot().started?
  end

  feature "the iPad row is touch-sized, icon-only, single-line, and controls the stage", %{
    session: session
  } do
    session =
      session
      |> resize_window(768, 1024)
      |> visit("/talk/notes/unlock/test-speaker-notes")
      |> assert_has(css("#speaker-controls"))
      |> click(css("#speaker-next"))
      |> assert_has(css("#speaker-note-2.current"))
      |> click(css("#speaker-live-full"))

    assert %{slide: 2, panel: :live_full} = Clock.snapshot()

    Clock.goto(17)
    session = assert_has(session, css(".speaker-controls-dynamic button", count: 5))

    {:ok, layout} =
      Wallaby.Chrome.execute_script(
        session,
        """
        const controls = document.getElementById('speaker-controls');
        const buttons = [...controls.querySelectorAll('button')];
        return {
          rows: new Set(buttons.map(button => Math.round(button.getBoundingClientRect().top))).size,
          minSize: Math.min(...buttons.map(button => button.getBoundingClientRect().width)),
          fits: controls.getBoundingClientRect().left >= 0 &&
            controls.getBoundingClientRect().right <= window.innerWidth,
          text: controls.innerText.trim()
        };
        """,
        []
      )

    assert layout["rows"] == 1
    assert layout["minSize"] >= 44
    assert layout["fits"]
    assert layout["text"] == ""
  end

  feature "every current iPad script is pinned at the top and clears the controls", %{
    session: session
  } do
    session =
      session
      |> resize_window(1024, 1509)
      |> visit("/talk/notes/unlock/test-speaker-notes")

    Enum.each(1..Deck.count(), fn slide ->
      Clock.goto(slide)
      session = assert_has(session, css("#speaker-note-#{slide}.current"))

      {:ok, layout} =
        Wallaby.Chrome.execute_script(
          session,
          """
          const current = document.querySelector('.speaker-note.current');
          const controls = document.getElementById('speaker-controls');
          const currentBox = current.getBoundingClientRect();
          const controlsBox = controls.getBoundingClientRect();

          return {
            top: Math.round(currentBox.top),
            bottom: Math.round(currentBox.bottom),
            controlsTop: Math.round(controlsBox.top)
          };
          """,
          []
        )

      assert layout["top"] in 20..28,
             "slide #{slide} starts at #{layout["top"]}px instead of the top"

      assert layout["bottom"] <= layout["controlsTop"] - 12,
             "slide #{slide} ends behind the controls"
    end)
  end

  feature "typing in an embedded form does not advance the deck", %{session: session} do
    session = visit(session, "/talk")

    # slide 15 is the diagnostics beat; revealing opens its pane
    Clock.goto(15)
    Clock.reveal()

    session
    |> assert_has(css("#diagnostic-prompt"))
    |> fill_in(css("#diagnostic-prompt"), with: "why ")
    |> send_keys([:space])
    |> assert_has(css("#deck-slide-15"))
  end
end
