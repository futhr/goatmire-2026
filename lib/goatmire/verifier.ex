defmodule Goatmire.Verifier do
  @moduledoc """
  The deployment gate: `ExMaude.IoT` plus a measured duration, a partitioned
  path, and an explicit `:unverified` outcome.

  A verdict is `:clean` (detector ran, no modelled conflict), `:conflicts`
  (detector ran, found some), or `:unverified` (detector could not run —
  interpreter missing, timeout, encoder rejection). `:unverified` is never
  collapsed into `:clean`; an availability failure must not look like a proof.

  `:clean` means no conflict *of the four types the bundled model encodes*.

  Emits `[:goatmire, :verify, :stop]` with `duration_us`, `rule_count`,
  `conflict_count`, tagged `status` and `scenario`.
  """

  @behaviour Goatmire.Gate

  alias Goatmire.Rules

  defmodule Verdict do
    @moduledoc "One verification result, with its measured cost and its scope."

    @type status :: :clean | :conflicts | :unverified

    @type t :: %__MODULE__{
            status: status(),
            conflicts: [map()],
            rule_count: non_neg_integer(),
            duration_us: non_neg_integer(),
            reason: term(),
            scope: String.t()
          }

    defstruct status: :unverified,
              conflicts: [],
              rule_count: 0,
              duration_us: 0,
              reason: nil,
              scope:
                "Evaluated against the four conflict types encoded in the bundled " <>
                  "iot-rules.maude model. A clean result is not a whole-system safety claim."
  end

  @doc """
  Verifies a rule set in one reduction.

  Options are passed through to `ExMaude.IoT.detect_conflicts/2`; `:scenario`
  is consumed here for telemetry metadata only.
  """
  @impl Goatmire.Gate
  @spec verify([Rules.rule()], keyword()) :: {:ok, Verdict.t()}
  def verify(rules, opts \\ []) do
    {scenario, maude_opts} = Keyword.pop(opts, :scenario)
    started_at = System.monotonic_time()

    verdict =
      case validated_detect(rules, maude_opts) do
        {:ok, []} ->
          %Verdict{status: :clean, conflicts: [], rule_count: length(rules)}

        {:ok, conflicts} ->
          %Verdict{status: :conflicts, conflicts: conflicts, rule_count: length(rules)}

        {:error, reason} ->
          %Verdict{status: :unverified, reason: reason, rule_count: length(rules)}
      end

    verdict = %{verdict | duration_us: elapsed_us(started_at)}

    stats = %{
      partitions: if(rules == [], do: 0, else: 1),
      pairs_considered: pair_count(length(rules)),
      pairs_skipped: 0
    }

    emit(verdict, scenario, stats)
    {:ok, verdict}
  end

  @doc """
  Verifies a large rule set as independent interaction partitions.

  Rules are joined conservatively when they share a bound Thing, write the
  same action target, or form a writer-to-trigger property edge. Returns a
  single merged verdict whose `duration_us` is the measured wall-clock of the
  whole pass, plus the partition count so the stage display can show the real
  reduction instead of a scripted percentage.

  Any partition that comes back `:unverified` makes the merged verdict
  `:unverified` — a partial pass is not a clean pass.
  """
  @impl Goatmire.Gate
  @spec verify_partitioned([Rules.rule()], keyword()) ::
          {:ok, Verdict.t(), Goatmire.Gate.stats()}
  def verify_partitioned(rules, opts \\ []) do
    {scenario, maude_opts} = Keyword.pop(opts, :scenario)
    started_at = System.monotonic_time()

    {verdict, stats} = partitioned_result(rules, maude_opts)
    verdict = %{verdict | duration_us: elapsed_us(started_at)}

    emit(verdict, scenario, stats)

    {:ok, verdict, stats}
  end

  @doc """
  Splits a rule set into the rules a `:conflicts` verdict would block and the
  rules it would let through.

  Used by the storm beat to build the enforced rule set. Every rule named on
  either side of a conflict is withheld — the gate does not guess which of the
  two authors was right, it refuses the pair and surfaces it for review.
  """
  @impl Goatmire.Gate
  @spec split_on_verdict([Rules.rule()], Verdict.t()) ::
          %{admitted: [Rules.rule()], withheld: [Rules.rule()]}
  def split_on_verdict(rules, %Verdict{status: :conflicts, conflicts: conflicts}) do
    blocked =
      conflicts
      |> Enum.flat_map(fn conflict ->
        [Map.get(conflict, :rule1), Map.get(conflict, :rule2)]
      end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    {withheld, admitted} = Enum.split_with(rules, &MapSet.member?(blocked, &1.id))
    %{admitted: admitted, withheld: withheld}
  end

  def split_on_verdict(rules, %Verdict{status: :clean}) do
    %{admitted: rules, withheld: []}
  end

  def split_on_verdict(rules, %Verdict{status: :unverified}) do
    # Fail closed. An unverified rule set is not an admitted rule set.
    %{admitted: [], withheld: rules}
  end

  @doc """
  Whether a usable Maude interpreter is reachable, and which version.

  `mix goatmire.health` uses this local interpreter check. ExMaude discovers
  its configured, package-local, or `PATH` interpreter. A version string alone
  is not a usable gate: without the worker pool this application cannot obtain
  a verdict, so that case reports an error instead of a version. A pool whose
  workers are all busy is still usable. This does not check optional MQTT or
  language-model services.
  """
  @impl Goatmire.Gate
  @spec health() :: {:ok, String.t()} | {:error, term()}
  def health do
    with {:ok, version} <- ExMaude.version(),
         :ok <- pool_available() do
      {:ok, version}
    end
  rescue
    error -> {:error, error}
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp pool_available do
    case ExMaude.Pool.status() do
      %{state: :not_started} -> {:error, :verifier_pool_unavailable}
      %{size: 0} -> {:error, :verifier_pool_unavailable}
      %{} -> :ok
    end
  end

  # ExMaude returns {:error, _} for input and backend failures, but a missing
  # interpreter or a dead pool worker surfaces as an exit or a raise. All three
  # are the same thing to the gate: we did not get an answer.
  defp safe_detect(rules, opts) do
    ExMaude.IoT.detect_conflicts(rules, opts)
  rescue
    error -> {:error, error}
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp validated_detect(rules, opts) do
    with :ok <- validate_rule_set(rules) do
      safe_detect(rules, opts)
    end
  end

  defp partitioned_result(rules, maude_opts) do
    total = length(rules)

    case validate_rule_set(rules) do
      :ok ->
        partitions = Rules.partition(rules)
        deadline = System.monotonic_time(:millisecond) + Keyword.get(maude_opts, :timeout, 15_000)

        results = detect_partitions(partitions, maude_opts, deadline)

        {merge_results(results, total), partition_stats(partitions, total)}

      {:error, reason} ->
        {%Verdict{status: :unverified, reason: reason, rule_count: total}, empty_stats()}
    end
  end

  defp detect_partitions(partitions, opts, deadline) do
    Enum.reduce_while(partitions, [], fn partition, results ->
      remaining = deadline - System.monotonic_time(:millisecond)

      result =
        if remaining > 0,
          do: safe_detect(partition, Keyword.put(opts, :timeout, remaining)),
          else: {:error, :timeout}

      case result do
        {:ok, _} -> {:cont, [result | results]}
        {:error, _} -> {:halt, [result | results]}
      end
    end)
  end

  defp validate_rule_set(rules), do: ExMaude.IoT.validate_rules(rules)

  defp merge_results(results, total) do
    case Enum.find(results, &match?({:error, _}, &1)) do
      {:error, reason} ->
        %Verdict{status: :unverified, reason: reason, rule_count: total}

      nil ->
        conflicts = Enum.flat_map(results, fn {:ok, list} -> list end)
        status = if conflicts == [], do: :clean, else: :conflicts
        %Verdict{status: status, conflicts: conflicts, rule_count: total}
    end
  end

  defp partition_stats(partitions, total) do
    pairs_considered = Enum.sum(Enum.map(partitions, &pair_count(length(&1))))

    %{
      partitions: length(partitions),
      pairs_considered: pairs_considered,
      pairs_skipped: pair_count(total) - pairs_considered
    }
  end

  defp empty_stats, do: %{partitions: 0, pairs_considered: 0, pairs_skipped: 0}

  defp elapsed_us(started_at) do
    System.convert_time_unit(System.monotonic_time() - started_at, :native, :microsecond)
  end

  defp pair_count(n) when n < 2, do: 0
  defp pair_count(n), do: div(n * (n - 1), 2)

  defp emit(%Verdict{} = verdict, scenario, stats) do
    conflict_types =
      verdict.conflicts
      |> Enum.map(&Map.get(&1, :type))
      |> Enum.uniq()

    :telemetry.execute(
      [:goatmire, :verify, :stop],
      %{
        duration_us: verdict.duration_us,
        rule_count: verdict.rule_count,
        conflict_count: length(verdict.conflicts),
        partitions: stats.partitions,
        pairs_considered: stats.pairs_considered,
        pairs_skipped: stats.pairs_skipped
      },
      %{
        status: verdict.status,
        scenario: scenario,
        conflict_types: conflict_types
      }
    )
  end
end
