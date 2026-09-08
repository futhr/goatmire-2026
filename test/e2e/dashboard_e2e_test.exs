defmodule GoatmireWeb.DashboardE2ETest do
  @moduledoc false

  use GoatmireWeb.E2ECase,
    async: false,
    browser_context_opts: [viewport: %{width: 1_440, height: 1_000}]

  alias Goatmire.{Engine, Fleet, StubVerifier}

  @moduletag :e2e
  @moduletag timeout: 60_000

  setup do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    Fleet.stop_all()
    :ok = Engine.undeploy()
    :ok = Engine.reset()

    on_exit(fn ->
      Fleet.stop_all()
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
    end)

    :ok
  end

  test "primary navigation crosses every LiveView over a connected browser", %{conn: conn} do
    conn
    |> visit("/warehouse")
    |> assert_has("#warehouse-dashboard")
    |> click_link("Rule gate")
    |> assert_has("#rule-dashboard")
    |> click_link("Verifier")
    |> assert_has("#verify-dashboard")
    |> click_link("Diagnostics")
    |> assert_has("#diagnostic-dashboard")
    |> assert_has("[data-phx-main].phx-connected")
  end

  test "warehouse controls run a measured one-second observe scenario", %{conn: conn} do
    StubVerifier.set(:clean)

    conn
    |> visit("/warehouse")
    |> assert_has("[data-phx-main].phx-connected")
    |> set_storm_controls(3, 1)
    |> assert_has("#fleet-size", value: "3")
    |> assert_has("#storm-duration", value: "1")
    |> click("#run-observe")
    |> assert_has("#shift-card", text: "Measured")
    |> assert_has("#shift-card", text: "observe")
    |> assert_has("#alert-feed")
  end

  test "the research pair is rejected through the real rule-form and Maude workflow", %{
    conn: conn
  } do
    [first, second] = Goatmire.Rules.research_state_conflict_pair()

    Application.put_env(:goatmire, :verifier, Goatmire.Verifier)

    conn
    |> visit("/rules")
    |> assert_has("[data-phx-main].phx-connected")
    |> click("#deploy-rule-a")
    |> assert_has(".flash", text: "Deployed the reproduced")
    |> click("#load-rule-b")
    |> assert_has("#rule-id", value: second.id)
    |> click("#check-rule")
    |> assert_has("#rule-dashboard .badge.conflicts", text: "CONFLICT FOUND")
    |> evaluate("document.body.innerText", fn page_text ->
      assert page_text =~ "CONFLICT FOUND", page_text
    end)
    |> assert_has("#rule-dashboard", text: first.id)
    |> assert_has("#rule-dashboard", text: second.id)
    |> GoatmireWeb.E2ELayout.assert_layout("#rule-dashboard", 2, false)
  end

  defp set_storm_controls(conn, fleet_size, duration) do
    evaluate(
      conn,
      """
      ([fleetSize, durationValue]) => {
        const fleet = document.getElementById('fleet-size');
        const duration = document.getElementById('storm-duration');
        fleet.value = fleetSize;
        duration.value = durationValue;
        fleet.dispatchEvent(new Event('input', {bubbles: true}));
        fleet.dispatchEvent(new Event('change', {bubbles: true}));
        duration.dispatchEvent(new Event('input', {bubbles: true}));
        duration.dispatchEvent(new Event('change', {bubbles: true}));
        return [fleet.value, duration.value];
      }
      """,
      [is_function: true, arg: [Integer.to_string(fleet_size), Integer.to_string(duration)]],
      fn values ->
        assert values == [Integer.to_string(fleet_size), Integer.to_string(duration)]
      end
    )
  end
end

defmodule GoatmireWeb.DashboardLayoutE2ETest do
  @moduledoc false

  use GoatmireWeb.E2ECase,
    async: false,
    parameterize: [
      %{
        browser_context_opts: [viewport: %{width: 1_440, height: 1_000}],
        column_mode: :desktop,
        touch?: false
      },
      %{
        browser_context_opts: [viewport: %{width: 820, height: 1_180}, has_touch: true],
        column_mode: :tablet,
        touch?: true
      },
      %{
        browser_context_opts: [viewport: %{width: 390, height: 844}, has_touch: true],
        column_mode: :mobile,
        touch?: true
      },
      %{
        browser_context_opts: [viewport: %{width: 320, height: 720}, has_touch: true],
        column_mode: :mobile,
        touch?: true
      }
    ]

  @moduletag :e2e
  @moduletag timeout: 60_000

  test "dashboard surfaces fit the viewport", %{
    conn: conn,
    column_mode: column_mode,
    touch?: touch?
  } do
    pages = [
      {"/warehouse", "#warehouse-dashboard", 1},
      {"/rules", "#rule-dashboard", 2},
      {"/verify", "#verify-dashboard", 2},
      {"/diagnostics", "#diagnostic-dashboard", 1}
    ]

    Enum.reduce(pages, conn, fn {path, dashboard, tablet_columns}, conn ->
      expected_columns = expected_columns(column_mode, tablet_columns)

      conn
      |> visit(path)
      |> GoatmireWeb.E2ELayout.assert_layout(dashboard, expected_columns, touch?)
    end)
  end

  defp expected_columns(:desktop, _), do: 2
  defp expected_columns(:tablet, tablet_columns), do: tablet_columns
  defp expected_columns(:mobile, _), do: 1
end

defmodule GoatmireWeb.E2ELayout do
  @moduledoc false

  import ExUnit.Assertions
  import PhoenixTest.Playwright, only: [evaluate: 4]

  @spec assert_layout(PhoenixTest.Playwright.t(), String.t(), pos_integer(), boolean()) ::
          PhoenixTest.Playwright.t()
  def assert_layout(conn, dashboard, expected_columns, touch?) do
    evaluate(
      conn,
      """
      (dashboardSelector) => {
        const dashboard = document.querySelector(dashboardSelector);
        const nav = document.querySelector('header nav');
        const visibleTargets = [...document.querySelectorAll(
          'button, input, select, textarea, header a'
        )].filter((element) => {
          const rect = element.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0;
        });
        return {
          innerWidth: window.innerWidth,
          scrollWidth: document.documentElement.scrollWidth,
          dashboardColumns: getComputedStyle(dashboard).gridTemplateColumns.split(' ').length,
          dashboardRight: Math.ceil(dashboard.getBoundingClientRect().right),
          navRight: Math.ceil(nav.getBoundingClientRect().right),
          navDisplay: getComputedStyle(nav).display,
          navColumns: getComputedStyle(nav).gridTemplateColumns.split(' ').length,
          minimumTargetHeight: Math.min(...visibleTargets.map((element) =>
            element.getBoundingClientRect().height
          ))
        };
      }
      """,
      [is_function: true, arg: dashboard],
      fn result ->
        assert result["scrollWidth"] <= result["innerWidth"] + 1,
               "horizontal overflow: #{inspect(result)}"

        assert result["dashboardRight"] <= result["innerWidth"] + 1
        assert result["navRight"] <= result["innerWidth"] + 1

        assert result["dashboardColumns"] == expected_columns,
               "unexpected dashboard columns: #{inspect(result)}"

        if touch?, do: assert(result["minimumTargetHeight"] >= 44)

        if result["innerWidth"] <= 640 do
          assert result["navDisplay"] == "grid"
          assert result["navColumns"] == 2
        end
      end
    )
  end
end
