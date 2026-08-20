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

  `mix goatmire.health` calls this instead of probing a remote service — the
  only external dependency this demo has left is the interpreter on `PATH`.
  """
  @impl Goatmire.Gate
  @spec health() :: {:ok, String.t()} | {:error, term()}
  def health do
    case ExMaude.version() do
      {:ok, version} -> {:ok, version}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  catch
    :exit, reason -> {:error, {:exit, reason}}
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
        results = Enum.map(partitions, &safe_detect(&1, maude_opts))
        {merge_results(results, total), partition_stats(partitions, total)}

      {:error, reason} ->
        {%Verdict{status: :unverified, reason: reason, rule_count: total}, empty_stats()}
    end
  end

  defp validate_rule_set(rules) do
    case ExMaude.IoT.validate_rules(rules) do
      :ok -> validate_unique_ids(rules)
      {:error, _} = error -> error
    end
  end

  defp validate_unique_ids(rules) do
    duplicates =
      rules
      |> Enum.map(& &1.id)
      |> Enum.frequencies()
      |> Enum.filter(fn {_, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    if duplicates == [], do: :ok, else: {:error, {:duplicate_rule_ids, duplicates}}
  end

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
