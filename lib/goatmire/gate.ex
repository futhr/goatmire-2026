defmodule Goatmire.Gate do
  @moduledoc """
  The gate's interface, and the seam where it can be swapped.

  Callers go through here rather than `Goatmire.Verifier` directly, so the
  suite can substitute a scripted gate — the only way to exercise the
  `:unverified` branch on a machine where Maude works.

  Configure with `config :goatmire, verifier: MyModule`.
  """

  alias Goatmire.Verifier.Verdict

  @type stats :: %{
          partitions: non_neg_integer(),
          pairs_considered: non_neg_integer(),
          pairs_skipped: non_neg_integer()
        }

  @doc "Reduces a candidate rule set and returns a verdict."
  @callback verify([map()], keyword()) :: {:ok, Verdict.t()}

  @doc "Splits a rule set into what a verdict admits and what it withholds."
  @callback split_on_verdict([map()], Verdict.t()) :: %{
              admitted: [map()],
              withheld: [map()]
            }

  @doc """
  Reduces a rule set as independent partitions. What a deployment path should
  call — a whole-corpus reduction times out on any realistic set.
  """
  @callback verify_partitioned([map()], keyword()) ::
              {:ok, Verdict.t(), stats()}

  @doc "Whether a usable interpreter is reachable, and which version."
  @callback health() :: {:ok, String.t()} | {:error, term()}

  @doc "The configured gate implementation."
  @spec impl() :: module()
  def impl, do: Application.get_env(:goatmire, :verifier, Goatmire.Verifier)

  @doc "Delegates whole-set verification to the configured gate."
  @spec verify([map()], keyword()) :: {:ok, Verdict.t()}
  def verify(rules, opts \\ []), do: impl().verify(rules, opts)

  @doc "Delegates partitioned verification to the configured gate."
  @spec verify_partitioned([map()], keyword()) ::
          {:ok, Verdict.t(), stats()}
  def verify_partitioned(rules, opts \\ []), do: impl().verify_partitioned(rules, opts)

  @doc "Delegates admission splitting to the configured gate."
  @spec split_on_verdict([map()], Verdict.t()) :: %{admitted: [map()], withheld: [map()]}
  def split_on_verdict(rules, verdict), do: impl().split_on_verdict(rules, verdict)

  @doc "Reports whether the configured gate can reach a Maude interpreter."
  @spec health() :: {:ok, String.t()} | {:error, term()}
  def health, do: impl().health()
end
