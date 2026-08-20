defmodule GoatmireWeb.DashboardE2ETest do
  @moduledoc false

  use ExUnit.Case, async: false
  use Wallaby.Feature

  import Wallaby.Query

  alias Goatmire.{Engine, Fleet, StubVerifier}

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

  feature "primary navigation crosses every LiveView over a connected browser", %{
    session: session
  } do
    session
    |> visit("/warehouse")
    |> assert_has(css("#warehouse-dashboard"))
    |> click(link("Rule gate"))
    |> assert_has(css("#rule-dashboard"))
    |> click(link("Verifier"))
    |> assert_has(css("#verify-dashboard"))
    |> click(link("Diagnostics"))
    |> assert_has(css("#diagnostic-dashboard"))
    |> assert_has(css("[data-phx-main].phx-connected"))
  end

  feature "warehouse controls run a measured one-second observe scenario", %{session: session} do
    StubVerifier.set(:clean)

    session =
      session
      |> visit("/warehouse")
      |> assert_has(css("[data-phx-main].phx-connected"))

    :ok = set_storm_controls(session, 3, 1)

    session
    |> assert_has(css("#fleet-size[data-server-value='3']"))
    |> assert_has(css("#storm-duration[data-server-value='1']"))

    session
    |> click(css("#run-observe"))
    |> assert_has(css("#shift-card", text: "Measured"))
    |> assert_has(css("#shift-card", text: "observe"))
    |> assert_has(css("#alert-feed"))
  end

  feature "the research pair is rejected through the real rule-form and Maude workflow", %{
    session: session
  } do
    [first, second] = Goatmire.Rules.research_state_conflict_pair()

    Application.put_env(:goatmire, :verifier, Goatmire.Verifier)

    session =
      session
      |> resize_window(390, 844)
      |> visit("/rules/new")
      |> assert_has(css("[data-phx-main].phx-connected"))
      |> click(css("#deploy-rule-a"))
      |> assert_has(css(".flash", text: "Deployed the reproduced"))

    session = session |> click(css("#load-rule-b"))
    assert Wallaby.Browser.has_value?(session, css("#rule-id"), second.id)

    session =
      session
      |> click(css("#check-rule"))
      |> assert_has(css("#rule-dashboard .badge.conflicts", text: "CONFLICT FOUND"))

    {:ok, page_text} =
      Wallaby.Chrome.execute_script(session, "return document.body.innerText;", [])

    assert page_text =~ "CONFLICT FOUND", page_text

    session
    |> assert_has(css("#rule-dashboard", text: first.id))
    |> assert_has(css("#rule-dashboard", text: second.id))

    assert_layout(session, "#rule-dashboard", 1, true)
  end

  feature "dashboard surfaces fit desktop, tablet and mobile viewports", %{session: session} do
    pages = [
      {"/warehouse", "#warehouse-dashboard", 1},
      {"/rules/new", "#rule-dashboard", 2},
      {"/verify", "#verify-dashboard", 2},
      {"/diagnostics", "#diagnostic-dashboard", 1}
    ]

    for {width, height, column_mode, touch?} <- [
          {1_440, 1_000, :desktop, false},
          {820, 1_180, :tablet, true},
          {390, 844, :mobile, true},
          {320, 720, :mobile, true}
        ],
        {path, dashboard, tablet_columns} <- pages do
      session = resize_window(session, width, height)
      session = visit(session, path)
      columns = expected_columns(column_mode, tablet_columns)

      assert_layout(session, dashboard, columns, touch?)
    end
  end

  defp expected_columns(:desktop, _), do: 2
  defp expected_columns(:tablet, tablet_columns), do: tablet_columns
  defp expected_columns(:mobile, _), do: 1

  defp set_storm_controls(session, fleet_size, duration) do
    {:ok, _} =
      Wallaby.Chrome.execute_script(
        session,
        """
        const fleet = document.getElementById('fleet-size');
        const duration = document.getElementById('storm-duration');
        fleet.value = arguments[0];
        duration.value = arguments[1];
        duration.dispatchEvent(new Event('input', {bubbles: true}));
        duration.dispatchEvent(new Event('change', {bubbles: true}));
        return [fleet.value, duration.value];
        """,
        [Integer.to_string(fleet_size), Integer.to_string(duration)]
      )

    :ok
  end

  defp assert_layout(session, dashboard, expected_columns, touch?) do
    {:ok, result} =
      Wallaby.Chrome.execute_script(
        session,
        """
        const dashboard = document.querySelector(arguments[0]);
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
        """,
        [dashboard]
      )

    assert result["scrollWidth"] <= result["innerWidth"] + 1,
           "horizontal overflow: #{inspect(result)}"

    assert result["dashboardRight"] <= result["innerWidth"] + 1
    assert result["navRight"] <= result["innerWidth"] + 1

    assert result["dashboardColumns"] == expected_columns,
           "unexpected dashboard columns: #{inspect(result)}"

    if touch? do
      assert result["minimumTargetHeight"] >= 44
    end

    if result["innerWidth"] <= 640 do
      assert result["navDisplay"] == "grid"
      assert result["navColumns"] == 2
    end

    :ok
  end
end
