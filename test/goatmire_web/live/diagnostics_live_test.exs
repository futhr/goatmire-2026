defmodule GoatmireWeb.DiagnosticsLiveTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import Phoenix.{ConnTest, LiveViewTest}

  @endpoint GoatmireWeb.Endpoint

  alias Beamlens.Operator.{CompletionResult, Notification, Snapshot}
  alias GoatmireWeb.DiagnosticsLive

  setup do
    saved = %{
      codex: Application.get_env(:goatmire, :diagnostics_codex_runner),
      ollama: Application.get_env(:goatmire, :diagnostics_ollama_runner)
    }

    Application.put_env(:goatmire, :diagnostics_codex_runner, Goatmire.FakeCodexRunner)
    Application.put_env(:goatmire, :diagnostics_ollama_runner, Goatmire.FakeOllamaRunner)

    on_exit(fn ->
      restore_env(:diagnostics_codex_runner, saved.codex)
      restore_env(:diagnostics_ollama_runner, saved.ollama)
    end)

    :ok
  end

  test "renders live evidence without calling an LLM on page load" do
    {:ok, _, html} = live(build_conn(), "/diagnostics")

    assert html =~ "Ask the running system"
    assert html =~ "alerts / second"
    assert html =~ "BEAM run queue"
    assert html =~ "Ask"
    assert html =~ "reasoner not used yet" or html =~ "Codex" or html =~ "Ollama"
    assert html =~ ~s(id="diagnostic-dashboard")
    assert html =~ ~s(id="diagnostic-prompt")
  end

  test "stage prompts can be selected and cleared without model work" do
    {:ok, live, _} = live(build_conn(), "/diagnostics")
    prompt = "Is Maude pool saturation or rule semantics causing this run?"

    html = render_click(live, "set_prompt", %{"prompt" => prompt})
    assert html =~ prompt

    clear = element(live, "#clear-diagnosis")
    html = render_click(clear)
    assert html =~ ~s(id="diagnostic-prompt")
    refute html =~ ">#{prompt}</textarea>"
  end

  test "a malformed diagnose event is an error rather than a LiveView crash" do
    {:ok, live, _} = live(build_conn(), "/diagnostics")

    html = render_click(live, "diagnose", %{})

    assert html =~ "Enter a diagnostic question"
    assert Process.alive?(live.pid)
  end

  test "a submitted question completes through the supervised analysis boundary" do
    {:ok, live, _} = live(build_conn(), "/diagnostics")
    prompt = "Does this snapshot actually show rising alerts?"

    live
    |> form("#diagnostic-form", %{"diagnostics" => %{"prompt" => prompt}})
    |> render_submit()

    terminal? = fn html ->
      html =~ "hypothesis grounded:" or html =~ "BeamLens could not complete this analysis"
    end

    html = eventually_render(live, terminal?)
    assert html =~ prompt

    if html =~ "hypothesis grounded:" do
      assert html =~ "observation"
      assert html =~ "current.engine.rates_per_second.alerts="
    else
      assert html =~ ~s(role="alert")
      refute html =~ "GenServer"
      refute html =~ "#PID"
    end

    assert has_element?(live, "#ask-beamlens:not([disabled])")
  end

  test "provider state changes stay visible without affecting deterministic evidence" do
    {:ok, live, _} = live(build_conn(), "/diagnostics")

    for {status, label} <- [
          {%{state: :available, provider: :codex, plan_type: "pro"}, "Codex ready"},
          {%{state: :available, provider: :ollama, reason: "plan unavailable"}, "Ollama ready"},
          {%{state: :running}, "checking plan access"},
          {%{state: :unavailable}, "diagnostics unavailable"}
        ] do
      send(live.pid, {:diagnostics_provider, status})
      assert render(live) =~ label
      assert has_element?(live, "#deterministic-evidence")
    end
  end

  test "mounts the full BeamLens inspector separately" do
    conn = get(build_conn(), "/beamlens")
    assert html_response(conn, 200) =~ "<title>Beamlens</title>"
  end

  test "renders exact snapshot fields when an operator returns no anomaly insight" do
    snapshot =
      Snapshot.new(%{
        current: %{
          mode: nil,
          verification: nil,
          engine: %{rates_per_second: %{alerts: 0}}
        }
      })

    diagnosis =
      DiagnosticsLive.format_diagnosis(%{
        insights: [],
        operator_results: [
          %CompletionResult{state: :healthy, notifications: [], snapshots: [snapshot]}
        ]
      })

    assert diagnosis.summaries == [
             "No verification has been recorded; the measured alert rate is 0/s."
           ]

    assert "current.verification.status=not_recorded" in diagnosis.observations
    assert "current.engine.rates_per_second.alerts=0" in diagnosis.observations
    assert diagnosis.hypotheses == []
  end

  test "renders deterministic stage evidence separately from model inference" do
    diagnosis =
      DiagnosticsLive.format_diagnosis(%{
        stage_answer: %{
          summaries: ["The runtime is healthy while rule behavior needs inspection."],
          observations: ["current.beam.run_queue=0", "current.maude.pool.in_use=0"],
          hypotheses: ["Inspect the active rule pair."],
          confidence: [:medium],
          grounded: false
        }
      })

    assert diagnosis.observations == [
             "current.beam.run_queue=0",
             "current.maude.pool.in_use=0"
           ]

    assert diagnosis.hypotheses == ["Inspect the active rule pair."]
    refute diagnosis.grounded
  end

  test "renders BeamLens operator facts separately from an ungrounded hypothesis" do
    notification =
      Notification.new(%{
        operator: Goatmire.Diagnostics.Skill,
        anomaly_type: "diagnostic_summary",
        severity: :warning,
        context: "mode=observe, verdict=conflicts",
        observation: "current.engine.rates_per_second.alerts=12",
        hypothesis: "The conflicting pair might explain the rate.",
        snapshots: []
      })

    diagnosis =
      DiagnosticsLive.format_diagnosis(%{
        insights: [],
        operator_results: [
          %CompletionResult{
            state: :warning,
            notifications: [notification],
            snapshots: []
          }
        ]
      })

    assert diagnosis.summaries == ["mode=observe, verdict=conflicts"]
    assert diagnosis.observations == ["current.engine.rates_per_second.alerts=12"]
    assert diagnosis.hypotheses == ["The conflicting pair might explain the rate."]
    refute diagnosis.grounded
  end

  test "normalises multiple correlated insights and the empty-result fallback" do
    diagnosis =
      DiagnosticsLive.format_diagnosis(%{
        insights: [
          %{
            summary: "Runtime pressure is absent.",
            matched_observations: ["current.beam.run_queue=0", "current.maude.pool.in_use=0"],
            root_cause_hypothesis: nil,
            confidence: :high,
            hypothesis_grounded: true
          },
          %{
            summary: "The conflict witness remains relevant.",
            matched_observations: ["current.maude.pool.in_use=0"],
            root_cause_hypothesis: "Compare enforce mode.",
            confidence: :medium,
            hypothesis_grounded: false
          }
        ]
      })

    assert diagnosis.observations == [
             "current.beam.run_queue=0",
             "current.maude.pool.in_use=0"
           ]

    assert diagnosis.hypotheses == ["Compare enforce mode."]
    assert diagnosis.confidence == [:high, :medium]
    refute diagnosis.grounded

    assert %{confidence: [:low], grounded: false, hypotheses: []} =
             DiagnosticsLive.format_diagnosis(%{})
  end

  defp eventually_render(live, predicate, attempts \\ 50)

  defp eventually_render(live, predicate, attempts) when attempts > 0 do
    html = render(live)

    if predicate.(html) do
      html
    else
      Process.sleep(20)
      eventually_render(live, predicate, attempts - 1)
    end
  end

  defp eventually_render(live, _, 0), do: render(live)

  defp restore_env(key, nil), do: Application.delete_env(:goatmire, key)
  defp restore_env(key, value), do: Application.put_env(:goatmire, key, value)
end
