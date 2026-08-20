defmodule Goatmire.StubVerifier do
  @moduledoc """
  A verifier the suite can script.

  Lets the gate's decision logic be tested, including the fail-closed
  `:unverified` path — unreachable with a working interpreter installed.

      Goatmire.StubVerifier.set(:unverified)
      Goatmire.StubVerifier.set({:conflicts, [%{type: :state_conflict, rule1: "a", rule2: "b"}]})
      Goatmire.StubVerifier.set(:clean)
  """

  @behaviour Goatmire.Gate

  alias Goatmire.Verifier.Verdict

  @key {__MODULE__, :verdict}

  @doc "Scripts the next verdict. Applies process-globally via `:persistent_term`."
  @spec set(:clean | :unverified | {:conflicts, [map()]}) :: :ok
  def set(:clean), do: :persistent_term.put(@key, {:clean, []})
  def set(:unverified), do: :persistent_term.put(@key, {:unverified, []})
  def set({:conflicts, conflicts}), do: :persistent_term.put(@key, {:conflicts, conflicts})

  @doc "Restores the default (clean) verdict."
  @spec reset() :: :ok
  def reset, do: :persistent_term.put(@key, {:clean, []})

  @impl Goatmire.Gate
  def verify(rules, _ \\ []) do
    {status, conflicts} = :persistent_term.get(@key, {:clean, []})

    {:ok,
     %Verdict{
       status: status,
       conflicts: conflicts,
       rule_count: length(rules),
       duration_us: 42,
       reason: if(status == :unverified, do: :stubbed_unavailable)
     }}
  end

  @impl Goatmire.Gate
  def verify_partitioned(rules, opts \\ []) do
    {:ok, verdict} = verify(rules, opts)

    {:ok, verdict,
     %{
       partitions: if(rules == [], do: 0, else: 1),
       pairs_considered: div(length(rules) * max(length(rules) - 1, 0), 2),
       pairs_skipped: 0
     }}
  end

  @impl Goatmire.Gate
  defdelegate split_on_verdict(rules, verdict), to: Goatmire.Verifier

  @impl Goatmire.Gate
  def health, do: {:ok, "stub"}
end
