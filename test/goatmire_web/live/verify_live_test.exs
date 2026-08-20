defmodule GoatmireWeb.VerifyLiveTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Phoenix.{ConnTest, LiveViewTest}

  @endpoint GoatmireWeb.Endpoint

  alias Goatmire.StubVerifier

  setup do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()

    on_exit(fn ->
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
    end)

    %{conn: build_conn()}
  end

  test "renders the three rule sets and the policy panel", %{conn: conn} do
    {:ok, _, html} = live(conn, "/verify")

    assert html =~ "Two rules, one property"
    assert html =~ "Five unrelated rules"
    assert html =~ "The five-rule loop"
    assert html =~ "An agent policy"
  end

  test "states plainly when no interpreter is reachable", %{conn: conn} do
    {:ok, _, html} = live(conn, "/verify")

    # Whichever way the machine is set up, the page must commit to one of the
    # two statements — never leave the reader to assume.
    assert html =~ "maude reachable" or html =~ "maude unavailable"
  end

  test "runs the conflict panel and renders its scoped result", %{conn: conn} do
    StubVerifier.set(
      {:conflicts,
       [%{type: :state_conflict, rule1: "o3", rule2: "o4", reason: "opposing writes"}]}
    )

    {:ok, live, _} = live(conn, "/verify")
    conflict_button = element(live, "#verify-conflict")
    html = render_click(conflict_button)

    assert html =~ "conflict found"
    assert html =~ "opposing writes"
    assert html =~ "not a whole-system safety claim"
  end

  test "an unknown set does nothing and keeps the LiveView alive", %{conn: conn} do
    {:ok, live, _} = live(conn, "/verify")
    html = render_click(live, "run", %{"set" => "unknown"})

    assert html =~ "Two rules, one property"
    assert Process.alive?(live.pid)
  end
end
