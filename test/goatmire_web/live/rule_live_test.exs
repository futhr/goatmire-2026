defmodule GoatmireWeb.RuleLiveTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Phoenix.{ConnTest, LiveViewTest}

  alias Goatmire.{Engine, StubVerifier, Verifier}

  @endpoint GoatmireWeb.Endpoint

  setup do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    :ok = Engine.undeploy()

    on_exit(fn ->
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
    end)

    %{conn: build_conn()}
  end

  test "deployed fleet rules group into counted template chips", %{conn: conn} do
    rules =
      for n <- 1..3 do
        %{
          id: "agv-#{n}-low-battery-route",
          thing_id: "agv-#{n}",
          trigger: {:prop_lt, "battery", 20},
          actions: [{:set_prop, "agv-#{n}", "destination", "dock-7"}],
          priority: 1
        }
      end

    {:ok, _} = Engine.deploy(rules, mode: :enforce, scenario: :chip_test)

    {:ok, _, html} = live(conn, "/rules")

    assert html =~ "3 rule(s)"
    assert html =~ "low-battery-route"
    assert html =~ "×3"
    refute html =~ "agv-1-low-battery-route"
  end

  test "renders the form with the research-derived contact rule prefilled", %{conn: conn} do
    {:ok, _, html} = live(conn, "/rules")

    assert html =~ "Create a rule"
    assert html =~ "soteria-o3-contact-open-turn-on"
    assert html =~ "contact"
    assert html =~ "Research-derived demo"
  end

  test "a clean check offers a deploy button", %{conn: conn} do
    StubVerifier.set(:clean)
    {:ok, live, _} = live(conn, "/rules")

    html =
      live
      |> form("#rule-form", rule: valid_params())
      |> render_submit()

    assert html =~ "no modeled conflict"
    assert html =~ "Deploy"
  end

  test "a conflicting check shows the conflict and offers no deploy", %{conn: conn} do
    StubVerifier.set(
      {:conflicts,
       [
         %{
           type: :state_conflict,
           rule1: "soteria-o3-contact-open-turn-on",
           rule2: "new-rule",
           reason: "both write destination"
         }
       ]}
    )

    {:ok, live, _} = live(conn, "/rules")

    html =
      live
      |> form("#rule-form", rule: valid_params())
      |> render_submit()

    assert html =~ "conflict found"
    assert html =~ "state_conflict"
    assert html =~ "both write destination"
  end

  test "an unverified check is never presented as a pass", %{conn: conn} do
    StubVerifier.set(:unverified)
    {:ok, live, _} = live(conn, "/rules")

    html =
      live
      |> form("#rule-form", rule: valid_params())
      |> render_submit()

    assert html =~ "unverified"
    assert html =~ "The detector did not run"
    assert html =~ "Nothing was deployed"
    refute html =~ "no modeled conflict"
  end

  test "the loaded example is the reproduced O4 rule from the corpus", %{conn: conn} do
    {:ok, live, _} = live(conn, "/rules")

    html =
      live
      |> element("button", "Load rule B")
      |> render_click()

    assert html =~ "soteria-o4-contact-open-turn-off"
    assert html =~ "switch"
    assert html =~ "off"
  end

  test "the seeded O3 term remains in the actual candidate set", %{conn: conn} do
    StubVerifier.set(:clean)
    {:ok, live, _} = live(conn, "/rules")

    html =
      live
      |> element("button", "Deploy rule A")
      |> render_click()

    assert html =~ "soteria-o3-contact-open-turn-on"
    assert html =~ "against the 1 rule(s) already deployed"
  end

  @tag :maude
  test "the rehearsed O3/O4 button path returns the research-derived witness", %{conn: conn} do
    Application.put_env(:goatmire, :verifier, Verifier)
    {:ok, live, _} = live(conn, "/rules")

    live
    |> element("button", "Deploy rule A")
    |> render_click()

    live
    |> element("button", "Load rule B")
    |> render_click()

    html =
      live
      |> form("#rule-form")
      |> render_submit()

    assert html =~ "conflict found"
    assert html =~ "soteria-o3-contact-open-turn-on"
    assert html =~ "soteria-o4-contact-open-turn-off"
  end

  test "a tampered trigger operator is a form error, not a LiveView crash", %{conn: conn} do
    {:ok, live, _} = live(conn, "/rules")
    params = Map.put(valid_params(), "trigger_op", "not-an-operator")

    html = render_submit(live, "check", %{"rule" => params})

    assert html =~ "invalid trigger operator"
    assert Process.alive?(live.pid)
  end

  test "a forged deploy event cannot bypass the clean-verdict state", %{conn: conn} do
    {:ok, live, _} = live(conn, "/rules")

    html = render_click(live, "deploy", %{})

    assert html =~ "Run a clean verification before deploying"
    assert Engine.deployed_rules() == []
    assert Process.alive?(live.pid)
  end

  test "deployment rechecks against rules added after the form verdict", %{conn: conn} do
    StubVerifier.set(:clean)
    {:ok, live, _} = live(conn, "/rules")

    live
    |> form("#rule-form", rule: valid_params())
    |> render_submit()

    concurrent_rules = Goatmire.Rules.clean_set()
    assert {:ok, %{deployed: 5}} = Engine.deploy(concurrent_rules)

    deploy_button = element(live, "#deploy-checked-rule")
    render_click(deploy_button)

    deployed_rules = Engine.deployed_rules()
    deployed_ids = Enum.map(deployed_rules, & &1.id)
    assert "new-rule" in deployed_ids
    assert Enum.all?(concurrent_rules, &(&1.id in deployed_ids))
  end

  defp valid_params do
    %{
      "id" => "new-rule",
      "thing_id" => "agv-42",
      "trigger_op" => "prop_lt",
      "trigger_property" => "battery",
      "trigger_value" => "20",
      "action_property" => "destination",
      "action_value" => "dock-7"
    }
  end
end
