defmodule GoatmireWeb.PresenterE2ETest do
  @moduledoc false

  use ExUnit.Case, async: false
  use Wallaby.Feature

  import Wallaby.Query

  alias Goatmire.{Engine, StubVerifier}
  alias Goatmire.Talk.Clock

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

  feature "the presenter drives slides, panes, and chrome over a real browser", %{
    session: session
  } do
    session
    |> visit("/talk")
    |> assert_has(css("#presenter"))
    |> assert_has(css(".presenter-chrome", text: "1 / 18"))
    |> send_keys([:right_arrow])
    |> assert_has(css(".presenter-chrome", text: "2 / 18"))
    |> send_keys([:left_arrow])
    |> assert_has(css(".presenter-chrome", text: "1 / 18"))
    |> click(css("button[phx-value-panel='live_full']"))
    |> assert_has(css(".presenter-grid.live-full"))
    |> click(css("button[phx-value-panel='split']"))
    |> assert_has(css(".presenter-chrome"))

    assert Clock.snapshot().started?
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
    |> assert_has(css(".presenter-chrome", text: "15 / 18"))
  end
end
