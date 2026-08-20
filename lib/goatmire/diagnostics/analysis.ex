defmodule Goatmire.Diagnostics.Analysis do
  @moduledoc """
  One stage-facing BeamLens analysis, bounded and failure-safe.

  Checks provider availability and takes a skill snapshot before sending a
  single schema-constrained completion; idle snapshots and missing providers
  get deterministic answers with no model call. The model supplies only the
  inference and the next check — evidence lines come straight from the
  snapshot, so a hallucinated number cannot reach the screen. Exits and
  provider failures collapse to four public error reasons; LiveView never
  sees a pid or a raw call term.
  """

  alias Goatmire.Diagnostics.{Provider, Skill}

  @inferences ~w(rule_semantics runtime_pressure verifier_unavailable insufficient_evidence)
  @next_checks ~w(inspect_conflict_witness compare_enforce_run inspect_runtime retry_verifier inspect_raw_metrics)
  @confidences ~w(high medium low)

  @response_schema %{
    "type" => "object",
    "properties" => %{
      "inference" => %{"type" => "string", "enum" => @inferences},
      "next_check" => %{"type" => "string", "enum" => @next_checks},
      "confidence" => %{"type" => "string", "enum" => @confidences}
    },
    "required" => ["inference", "next_check", "confidence"],
    "additionalProperties" => false
  }

  @type error_reason ::
          :diagnostics_unavailable | :beamlens_timeout | :beamlens_busy | :beamlens_failed

  @doc """
  Runs one analysis inside a single overall deadline.

  `:availability`, `:snapshot`, `:runner`, and `:timeout` may be supplied by
  tests or alternate callers; production uses `Provider.refresh_status/0`,
  `Skill.snapshot/0`, the supervised diagnostic operator, and a 29-second
  deadline inside the dashboard's 30-second budget.
  """
  @spec run(String.t(), keyword()) :: {:ok, map()} | {:error, error_reason()}
  def run(prompt, opts \\ []) when is_binary(prompt) do
    timeout = Keyword.get(opts, :timeout, 29_000)
    started_at = System.monotonic_time(:millisecond)

    availability =
      Keyword.get_lazy(opts, :availability, &Provider.refresh_status/0)

    snapshot = Keyword.get_lazy(opts, :snapshot, &Skill.snapshot/0)
    runner = Keyword.get(opts, :runner, &run_operator/2)
    remaining = remaining_ms(started_at, timeout)

    cond do
      remaining <= 0 ->
        {:error, :beamlens_timeout}

      availability.available == false ->
        {:ok, %{stage_answer: unavailable_answer(snapshot)}}

      no_alert_activity?(snapshot) ->
        {:ok, %{stage_answer: idle_answer(snapshot)}}

      true ->
        invoke(runner, %{reason: prompt, snapshot: snapshot}, remaining)
    end
  end

  @doc false
  @spec error_message(error_reason() | term()) :: String.t()
  def error_message(:diagnostics_unavailable) do
    "Codex and Ollama are unavailable. Start either reasoner and retry; " <>
      "the deterministic evidence panel remains live."
  end

  def error_message(:beamlens_timeout) do
    "BeamLens did not finish within the 30-second stage deadline. " <>
      "The request was cancelled; retry or use the deterministic evidence panel."
  end

  def error_message(:beamlens_busy) do
    "BeamLens is already analysing another question. Wait for it to finish, then retry."
  end

  def error_message(_) do
    "BeamLens could not complete this analysis. Retry or use the " <>
      "deterministic evidence panel."
  end

  @doc false
  @spec build_stage_answer(map(), map()) :: map()
  def build_stage_answer(classification, snapshot) do
    classification = validate_classification(classification, snapshot)
    inference = classification.inference

    answer(
      summary_for(inference, snapshot),
      [inference_for(inference), next_check_for(classification.next_check)],
      snapshot,
      [confidence_atom(classification.confidence)],
      false
    )
  end

  defp remaining_ms(started_at, timeout) do
    timeout - (System.monotonic_time(:millisecond) - started_at)
  end

  defp invoke(runner, context, timeout) do
    runner.(context, timeout: timeout)
    |> normalize_result()
  rescue
    _ -> {:error, :beamlens_failed}
  catch
    :exit, {:timeout, _} -> {:error, :beamlens_timeout}
    :exit, :timeout -> {:error, :beamlens_timeout}
    :exit, _ -> {:error, :beamlens_failed}
  end

  defp run_operator(%{reason: reason, snapshot: snapshot}, _) do
    messages = [
      %{
        "role" => "system",
        "content" =>
          "Classify only the supplied bounded simulation evidence. JSON field names are " <>
            "authoritative: rates_per_second are rates and counters are totals. If " <>
            "verification is null, say no verdict was recorded; never infer clean or " <>
            "conflicts. If both the current alert rate and window alert total are zero, " <>
            "say the question's rising-alert premise is not present in this snapshot. " <>
            "Keep observations separate from inference. " <>
            "Maude—not this response—made any formal verdict. When status is conflicts, " <>
            "alerts are non-zero, and runtime fields are unsaturated, prefer rule_semantics " <>
            "and compare_enforce_run. Return only the requested inference, next_check, and " <>
            "confidence enums."
      },
      %{"role" => "user", "content" => stage_prompt(reason, snapshot)}
    ]

    response_format = %{
      "type" => "json_schema",
      "json_schema" => %{
        "name" => "goatmire_stage_diagnosis",
        "strict" => true,
        "schema" => @response_schema
      }
    }

    with {:ok, content, _} <-
           Provider.complete(messages,
             output_schema: @response_schema,
             response_format: response_format
           ),
         {:ok, response} <- Jason.decode(content),
         {:ok, classification} <- response_parts(response) do
      {:ok,
       %{
         stage_answer: build_stage_answer(classification, snapshot)
       }}
    else
      {:error, :diagnostics_unavailable} ->
        {:ok, %{stage_answer: unavailable_answer(snapshot)}}

      other ->
        other
    end
  end

  defp stage_prompt(reason, snapshot) do
    """
    Answer this stage question from the supplied bounded snapshot only:
    #{reason}

    The application renders exact evidence and prose separately. Classify the
    leading inference, choose one safe next simulation check, and rate your
    confidence. Do not invent a filename, rule identifier, field, or action.
    Do not claim that the model made the Maude verdict.

    Snapshot JSON:
    #{Jason.encode!(snapshot)}
    """
  end

  defp response_parts(response) when is_map(response) do
    inference = response[:inference] || response["inference"]
    next_check = response[:next_check] || response["next_check"]
    confidence = response[:confidence] || response["confidence"]

    if inference in @inferences and next_check in @next_checks and confidence in @confidences do
      {:ok, %{inference: inference, next_check: next_check, confidence: confidence}}
    else
      {:error, :invalid_response}
    end
  end

  defp response_parts(_), do: {:error, :invalid_response}

  defp validate_classification(classification, snapshot) do
    metrics = summary_metrics(snapshot)

    cond do
      metrics.verdict == "unverified" ->
        %{inference: "verifier_unavailable", next_check: "retry_verifier", confidence: "high"}

      metrics.verdict == "conflicts" and metrics.window_alerts > 0 and
          not runtime_saturated?(metrics) ->
        %{inference: "rule_semantics", next_check: "compare_enforce_run", confidence: "medium"}

      runtime_saturated?(metrics) ->
        %{inference: "runtime_pressure", next_check: "inspect_runtime", confidence: "medium"}

      true ->
        compatible_classification(classification)
    end
  end

  defp runtime_saturated?(metrics) do
    metrics.run_queue > 2 or
      (metrics.pool_size > 0 and metrics.pool_in_use >= metrics.pool_size)
  end

  defp compatible_classification(%{inference: "rule_semantics"} = classification) do
    if classification.next_check in ~w(inspect_conflict_witness compare_enforce_run),
      do: classification,
      else: %{classification | next_check: "compare_enforce_run"}
  end

  defp compatible_classification(%{inference: "runtime_pressure"} = classification),
    do: %{classification | next_check: "inspect_runtime"}

  defp compatible_classification(%{inference: "verifier_unavailable"} = classification),
    do: %{classification | next_check: "retry_verifier"}

  defp compatible_classification(%{inference: "insufficient_evidence"} = classification),
    do: %{classification | next_check: "inspect_raw_metrics"}

  defp summary_for("rule_semantics", snapshot) do
    metrics = summary_metrics(snapshot)

    "Alerts are flowing at **#{metrics.alert_rate}/s** — **#{metrics.window_alerts}** in " <>
      "the window — while the runtime itself is quiet (run queue #{metrics.run_queue}, " <>
      "Maude pool #{metrics.pool_in_use}/#{metrics.pool_size}). The recorded verdict is " <>
      "**#{metrics.verdict}** in #{metrics.mode} mode, so rule composition — deployed " <>
      "rules disagreeing about the same property — is the first cause to test."
  end

  defp summary_for("runtime_pressure", snapshot) do
    metrics = summary_metrics(snapshot)

    "Alerts are at **#{metrics.alert_rate}/s** and the runtime itself is under load: " <>
      "BEAM run queue **#{metrics.run_queue}**, Maude pool " <>
      "**#{metrics.pool_in_use}/#{metrics.pool_size}**. Saturation is the first cause " <>
      "to test; the formal verdict remains **#{metrics.verdict}** either way."
  end

  defp summary_for("verifier_unavailable", snapshot) do
    metrics = summary_metrics(snapshot)

    "There is no usable verdict — the recorded status is **#{metrics.verdict}** — so " <>
      "nothing can be concluded about rule semantics yet. Meanwhile the window holds " <>
      "**#{metrics.window_alerts}** alerts at **#{metrics.alert_rate}/s**."
  end

  defp summary_for("insufficient_evidence", snapshot) do
    metrics = summary_metrics(snapshot)

    "This snapshot does not isolate one cause: **#{metrics.alert_rate}** alerts/s, " <>
      "**#{metrics.window_alerts}** in the window, verdict **#{metrics.verdict}**, run " <>
      "queue #{metrics.run_queue}, Maude pool #{metrics.pool_in_use}/#{metrics.pool_size}. " <>
      "None of these fields dominates the others."
  end

  defp inference_for("rule_semantics") do
    "The formal conflict evidence plus an unsaturated runtime point at rule " <>
      "composition — two rules fighting over the same property — as the leading " <>
      "explanation. That does not prove every alert came from the witnessed pair."
  end

  defp inference_for("runtime_pressure") do
    "Runtime saturation is the leading explanation. This reasoner is not a profiler; " <>
      "corroborate with the raw series before acting."
  end

  defp inference_for("verifier_unavailable") do
    "Restore the verifier first — without a verdict, rule semantics cannot be compared."
  end

  defp inference_for("insufficient_evidence") do
    "This bounded snapshot does not isolate a cause."
  end

  defp next_check_for("inspect_conflict_witness"),
    do: "Next: open the conflict witness and read the two rule IDs it names."

  defp next_check_for("compare_enforce_run"),
    do:
      "Next: run the same staged storm in enforce mode and compare `window.alerts` " <>
        "between the two runs."

  defp next_check_for("inspect_runtime"),
    do:
      "Next: corroborate `current.beam.run_queue` and the Maude pool numbers in the " <>
        "raw metrics."

  defp next_check_for("retry_verifier"),
    do: "Next: restore Maude and rerun verification; until then the result stays unverified."

  defp next_check_for("inspect_raw_metrics"),
    do: "Next: read the named fields in Prometheus before forming a cause claim."

  defp confidence_atom("high"), do: :high
  defp confidence_atom("medium"), do: :medium
  defp confidence_atom("low"), do: :low

  defp summary_metrics(snapshot) do
    current = value(snapshot, :current, %{})
    engine = value(current, :engine, %{})
    rates = value(engine, :rates_per_second, %{})
    window = value(snapshot, :window, %{})
    verification = value(current, :verification, %{})
    maude = value(current, :maude, %{})
    pool = value(maude, :pool, %{})
    beam = value(current, :beam, %{})
    verdict = value(verification, :status, "not_recorded")

    %{
      alert_rate: value(rates, :alerts, 0),
      window_alerts: value(window, :alerts, 0),
      verdict: to_string(verdict),
      mode: value(current, :mode, "no_active_run"),
      run_queue: value(beam, :run_queue, 0),
      pool_in_use: value(pool, :in_use, 0),
      pool_size: value(pool, :size, 0)
    }
  end

  defp evidence_lines(snapshot) do
    current = value(snapshot, :current, %{})
    window = value(snapshot, :window, %{})
    engine = value(current, :engine, %{})
    rates = value(engine, :rates_per_second, %{})
    verification = value(current, :verification, %{})
    maude = value(current, :maude, %{})
    pool = value(maude, :pool, %{})
    beam = value(current, :beam, %{})

    [
      "current.engine.rates_per_second.alerts=#{value(rates, :alerts, 0)}",
      "current.engine.rates_per_second.events=#{value(rates, :events, 0)}",
      "window.alerts=#{value(window, :alerts, 0)}",
      "window.events=#{value(window, :events, 0)}",
      "current.mode=#{value(current, :mode, "no_active_run")}",
      "current.verification.status=#{value(verification, :status, "not_recorded")}",
      "current.maude.pool.in_use=#{value(pool, :in_use, 0)}",
      "current.maude.pool.size=#{value(pool, :size, 0)}",
      "current.beam.run_queue=#{value(beam, :run_queue, 0)}"
    ]
  end

  defp no_alert_activity?(snapshot) do
    current = value(snapshot, :current, %{})
    engine = value(current, :engine, %{})
    rates = value(engine, :rates_per_second, %{})
    window = value(snapshot, :window, %{})

    value(rates, :alerts, 0) == 0 and value(window, :alerts, 0) == 0
  end

  defp idle_answer(snapshot) do
    current = value(snapshot, :current, %{})
    verification = value(current, :verification, %{})

    summary =
      "Nothing is alerting right now — the live rate " <>
        "(`current.engine.rates_per_second.alerts`) and the window total " <>
        "(`window.alerts`) are both zero, so the question's premise is not in this " <>
        "snapshot. The last recorded verdict is " <>
        "**#{value(verification, :status, "not_recorded")}**; it describes the rule " <>
        "set, not current traffic."

    next_check =
      "Next: run a shift change in observe mode, watch `window.alerts` move, then ask again."

    answer(summary, [next_check], snapshot, [:high], true)
  end

  defp unavailable_answer(snapshot) do
    current = value(snapshot, :current, %{})
    verification = value(current, :verification, %{})
    window = value(snapshot, :window, %{})

    summary =
      "Neither Codex nor Ollama is reachable, so there is no model explanation — the " <>
        "deterministic evidence below is still live. The window holds " <>
        "**#{value(window, :alerts, 0)}** alerts and the last recorded verdict is " <>
        "**#{value(verification, :status, "not_recorded")}**."

    next_check =
      "Next: sign into Codex or start the pinned Ollama model, then retry for an explanation."

    answer(summary, [next_check], snapshot, [:high], true)
  end

  defp answer(summary, hypotheses, snapshot, confidence, grounded) do
    %{
      summaries: [summary],
      observations: evidence_lines(snapshot),
      hypotheses: hypotheses,
      confidence: confidence,
      grounded: grounded
    }
  end

  defp value(map, key, default) do
    case Map.get(map, key) do
      nil -> default
      found -> found
    end
  end

  defp normalize_result({:ok, result}) when is_map(result), do: {:ok, result}
  defp normalize_result({:error, :already_running}), do: {:error, :beamlens_busy}
  defp normalize_result({:error, _}), do: {:error, :beamlens_failed}
  defp normalize_result(_), do: {:error, :beamlens_failed}
end
