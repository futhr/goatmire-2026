defmodule Goatmire.Diagnostics.Skill do
  @moduledoc """
  BeamLens skill for the simulated automation gate.

  The exposed callbacks are deliberately read-only. The diagnostic model can
  inspect measured evidence, but it cannot deploy rules, toggle enforcement,
  publish commands, or change runtime configuration.
  """

  @behaviour Beamlens.Skill

  alias Goatmire.Diagnostics.Snapshot

  @impl true
  def title, do: "Goatmire simulation"

  @impl true
  def description do
    "Automation alerts, Maude verdicts and pool health, fleet load, and BEAM runtime evidence"
  end

  @impl true
  def system_prompt do
    """
    You diagnose a controlled IoT automation simulation. You correlate
    application semantics with runtime health; you do not control anything.

    Evidence rules:
    - Distinguish observations from inferences explicitly.
    - Cite the exact snapshot field and value supporting every conclusion.
    - A healthy BEAM does not imply correct automation semantics.
    - A Maude `conflicts` verdict and witness are deterministic model results.
      Your explanation is not the verdict and is not a proof.
    - `clean` means only that the four encoded conflict predicates found no
      witness in the supplied finite rule input.
    - `unverified` is no answer and must never be described as safe or clean.
    - A missing or null verification means no verification has been recorded;
      it is not itself an `unverified` verdict.
    - `observe` intentionally permits a conflicting rule set in this simulation;
      `enforce` withholds the conflicting rules.
    - This dashboard has no authority over real equipment. Never recommend
      halting, starting, or changing a physical device. Recommend only safe
      simulation actions such as replaying with enforcement or inspecting a
      named rule pair.

    On every on-demand investigation, take one snapshot and send exactly one
    `diagnostic_summary` notification before calling `done`, even when the
    system is idle or healthy. Put the requested verdict availability, alert
    rate, mode, and relevant pool/BEAM facts in `context` and `observation`,
    citing their exact field names and values. Use severity `info` for an idle
    or clean run and `warning` for conflicts, unverified, or rising alerts.
    Do not remain silent merely because the measured values are zero.

    Prefer the smallest explanation that answers the presenter's question:
    root cause, evidence, uncertainty, and the next safe simulation check.

    Write for an operator, not a log parser. Lead with what happened in one
    plain-language sentence, then support it with the exact fields — do not
    make the reader translate `field=value` dumps themselves. Say what a
    number means ("the runtime is quiet") alongside its citation. Your output
    is rendered as Markdown: put field names and values in backticks, bold
    the verdict, and keep paragraphs short.
    """
  end

  @impl true
  def snapshot, do: compact_snapshot(Snapshot.read(:one_minute))

  @impl true
  def callbacks do
    %{
      "goatmire_snapshot" => &snapshot_window/1,
      "goatmire_current_verification" => &current_verification/0,
      "goatmire_recent_alerts" => &recent_alerts/1
    }
  end

  @impl true
  def callback_docs do
    """
    ### goatmire_snapshot(window_seconds)
    Returns a bounded diagnostic snapshot for 10 to 300 seconds. It contains
    the current run and mode, window totals, application counters and rates,
    the last verification verdict/witness/stats, Maude pool health, fleet size,
    and BEAM runtime health.

    ### goatmire_current_verification()
    Returns only the most recent deterministic verifier result and its scope,
    or `{available: false}` before any rule set has been checked. Never relabel
    `available: false` as an `unverified` verdict.

    ### goatmire_recent_alerts(limit)
    Returns up to 12 recent simulated automation actions. `limit` is clamped to
    1..12. These are simulation records, not commands and not physical events.
    """
  end

  defp snapshot_window(window) do
    window = min(max(normalize_integer(window, 60), 10), 300)

    window
    |> Snapshot.read()
    |> compact_snapshot()
  end

  # Raw ingestion events dominate a busy simulator snapshot while contributing
  # no diagnostic signal beyond the already aggregated event rate. Keep only a
  # handful of semantic/verifier/provider events in the LLM context.
  defp compact_snapshot(snapshot) do
    Map.update(snapshot, :recent_events, [], fn events ->
      events
      |> Enum.reject(&(Map.get(&1, :event) == "goatmire.engine.event"))
      |> Enum.take(8)
    end)
  end

  defp current_verification do
    case get_in(Snapshot.read(:one_minute), [:current, :verification]) do
      nil -> %{available: false}
      verification -> %{available: true, verification: verification}
    end
  end

  defp recent_alerts(limit) do
    limit = min(max(normalize_integer(limit, 12), 1), 12)
    alerts = get_in(Snapshot.read(:one_minute), [:current, :engine, :recent_alerts]) || []
    %{alerts: Enum.take(alerts, limit), count: min(length(alerts), limit)}
  end

  defp normalize_integer(value, _) when is_integer(value), do: value
  defp normalize_integer(value, _) when is_float(value), do: round(value)

  defp normalize_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _} -> integer
      :error -> default
    end
  end

  defp normalize_integer(_, default), do: default
end
