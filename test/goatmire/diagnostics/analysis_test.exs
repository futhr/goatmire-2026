defmodule Goatmire.Diagnostics.AnalysisTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Goatmire.Diagnostics.Analysis

  test "the total deadline cancels a runner that ignores its timeout" do
    parent = self()

    result =
      Analysis.run("why?",
        availability: %{available: true},
        snapshot: active_snapshot(),
        timeout: 30,
        runner: fn _, _ ->
          send(parent, {:runner, self()})
          Process.sleep(:infinity)
        end
      )

    assert result == {:error, :beamlens_timeout}
    assert_receive {:runner, pid}
    refute Process.alive?(pid)
  end

  test "returns deterministic evidence without invoking a runner when no reasoner is available" do
    caller = self()
    snapshot = idle_snapshot()

    runner = fn _, _ ->
      send(caller, :runner_invoked)
      {:ok, %{}}
    end

    assert {:ok, %{stage_answer: answer}} =
             Analysis.run("why?",
               availability: %{available: false},
               snapshot: snapshot,
               runner: runner
             )

    refute_received :runner_invoked
    assert answer.summaries |> hd() =~ "Neither Codex nor Ollama is reachable"
    assert "window.alerts=0" in answer.observations
  end

  test "returns a successful injected BeamLens result" do
    runner = fn %{reason: "why?"}, opts ->
      assert opts[:timeout] > 0
      {:ok, %{insights: [], operator_results: []}}
    end

    assert {:ok, %{insights: []}} =
             Analysis.run("why?",
               availability: %{available: true},
               snapshot: active_snapshot(),
               runner: runner
             )
  end

  test "reduces a GenServer timeout exit to the public error vocabulary" do
    runner = fn _, _ -> exit({:timeout, {GenServer, :call, [:internal]}}) end

    assert {:error, :beamlens_timeout} =
             Analysis.run("why?",
               availability: %{available: true},
               snapshot: active_snapshot(),
               runner: runner
             )
  end

  test "does not expose arbitrary operator failures" do
    runner = fn _, _ -> {:error, {:provider, self(), :secret_internal_reason}} end

    assert {:error, :beamlens_failed} =
             Analysis.run("why?",
               availability: %{available: true},
               snapshot: active_snapshot(),
               runner: runner
             )
  end

  test "public failure messages never include raw failure terms" do
    internal = {:timeout, {GenServer, :call, [self(), :secret_internal_reason]}}
    message = Analysis.error_message(internal)

    assert message =~ "could not complete"
    refute message =~ "GenServer"
    refute message =~ "#PID"
    refute message =~ "secret_internal_reason"
  end

  test "idle snapshots replace model embellishment with a deterministic premise check" do
    caller = self()
    snapshot = idle_snapshot()

    runner = fn _, _ ->
      send(caller, :runner_invoked)
      {:ok, %{}}
    end

    assert {:ok, %{stage_answer: answer}} =
             Analysis.run("why?",
               availability: %{available: true},
               snapshot: snapshot,
               runner: runner
             )

    refute_received :runner_invoked

    assert [summary] = answer.summaries
    assert summary =~ "Nothing is alerting right now"
    assert summary =~ "`window.alerts`"
    assert summary =~ "**not_recorded**"

    assert "window.events=5600" in answer.observations

    assert answer.hypotheses == [
             "Next: run a shift change in observe mode, watch `window.alerts` move, then ask again."
           ]

    assert answer.confidence == [:high]
    assert answer.grounded
  end

  test "a model cannot invent conflict evidence when no verdict was recorded" do
    answer =
      Analysis.build_stage_answer(
        %{
          inference: "rule_semantics",
          next_check: "compare_enforce_run",
          confidence: "medium"
        },
        active_snapshot()
      )

    summary = hd(answer.summaries)
    assert summary =~ "**not_recorded**"
    assert summary =~ "does not isolate one cause"
    refute Enum.join(answer.hypotheses, " ") =~ "formal conflict evidence"
    refute summary =~ "iot-rules.maude"

    assert List.last(answer.hypotheses) ==
             "Next: read the named fields on the Metrics pane before forming a cause claim."

    assert answer.confidence == [:low]
  end

  test "unsupported classifications cannot replace clean or missing evidence" do
    for verdict <- [nil, %{status: :clean}],
        inference <-
          ~w(rule_semantics runtime_pressure verifier_unavailable insufficient_evidence) do
      snapshot = put_in(active_snapshot(), [:current, :verification], verdict)

      answer =
        Analysis.build_stage_answer(
          %{inference: inference, next_check: "inspect_conflict_witness", confidence: "high"},
          snapshot
        )

      assert hd(answer.summaries) =~ "does not isolate one cause"
      assert answer.confidence == [:low]
      refute Enum.join(answer.hypotheses, " ") =~ "rule IDs"
    end
  end

  test "recorded unverified and measured saturation constrain the explanation" do
    classification = %{
      inference: "rule_semantics",
      next_check: "inspect_conflict_witness",
      confidence: "high"
    }

    unverified = put_in(active_snapshot(), [:current, :verification], %{status: :unverified})
    answer = Analysis.build_stage_answer(classification, unverified)
    assert hd(answer.summaries) =~ "recorded status is **unverified**"
    assert List.last(answer.hypotheses) =~ "restore Maude"

    for verdict <- [nil, %{status: :clean}, %{status: :conflicts}] do
      saturated =
        active_snapshot()
        |> put_in([:current, :verification], verdict)
        |> put_in([:current, :beam, :run_queue], 3)

      answer = Analysis.build_stage_answer(classification, saturated)
      assert hd(answer.summaries) =~ "runtime itself is under load"
      refute Enum.join(answer.hypotheses, " ") =~ "formal conflict evidence"
    end
  end

  test "deterministic state corrects an incompatible model classification" do
    snapshot =
      active_snapshot()
      |> put_in([:current, :verification], %{status: :conflicts})

    answer =
      Analysis.build_stage_answer(
        %{
          inference: "insufficient_evidence",
          next_check: "retry_verifier",
          confidence: "low"
        },
        snapshot
      )

    assert hd(answer.summaries) =~ "rule composition"
    assert answer.confidence == [:medium]

    assert List.last(answer.hypotheses) ==
             "Next: run the same staged storm in enforce mode and compare `window.alerts` " <>
               "between the two runs."
  end

  defp idle_snapshot do
    %{
      current: %{
        mode: :enforce,
        verification: nil,
        engine: %{rates_per_second: %{alerts: 0, events: 1_400}},
        maude: %{pool: %{in_use: 0, size: 4}},
        beam: %{run_queue: 0}
      },
      window: %{alerts: 0, events: 5_600}
    }
  end

  defp active_snapshot do
    snapshot = idle_snapshot()
    put_in(snapshot, [:window, :alerts], 12)
  end
end
