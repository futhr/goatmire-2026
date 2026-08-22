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
    |> assert_has(css(".presenter-chrome", text: "1 / 25"))
    |> send_keys([:right_arrow])
    |> assert_has(css(".presenter-chrome", text: "2 / 25"))
    |> send_keys([:left_arrow])
    |> assert_has(css(".presenter-chrome", text: "1 / 25"))
    |> click(css("button[phx-value-panel='live_full']"))
    |> assert_has(css(".presenter-grid.live-full"))
    |> assert_has(css(".live-tabs button[phx-value-tab='metrics']"))
    |> click(css("button[phx-value-panel='split']"))
    |> click(css(".live-tabs button[phx-value-tab='metrics']"))
    |> assert_has(css(".live-tabs button.active[phx-value-tab='metrics']"))

    assert Clock.snapshot().started?
  end

  feature "typing in an embedded form does not advance the deck", %{session: session} do
    session
    |> visit("/talk")
    |> click(css("button[phx-value-panel='live_full']"))
    |> click(css(".live-tabs button[phx-value-tab='diagnostics']"))
    |> fill_in(css("#diagnostic-prompt"), with: "why ")
    |> send_keys([:space])
    |> assert_has(css(".presenter-chrome", text: "1 / 25"))
  end
end
