defmodule Goatmire.Console do
  @moduledoc """
  Small, stable operator surface for IEx and release remote shells.

  The dashboard is optional. Every stage-critical action remains available as
  an ordinary Elixir function so an operator can inspect terms, run the gate,
  stage a fleet, and ask diagnostics without copying internal GenServer calls.
  """

  alias Goatmire.Diagnostics.{Analysis, Provider, Snapshot}
  alias Goatmire.{Engine, Fleet, Gate, Rules}
  alias Goatmire.Scenario.Storm

  @default_question "Why did alerts rise, what verdict accompanies the run, and what should I inspect next?"

  @doc "Prints the available console workflow and returns `:ok`."
  @spec help() :: :ok
  def help do
    :io.put_chars("""
    Goatmire console

      GM.status()                  # engine, fleet, Maude and reasoner state
      GM.snapshot()                # bounded one-minute diagnostic snapshot
      GM.reset()                   # stop fleet, undeploy rules, clear runtime state
      GM.start_fleet(60)           # supervised local simulated devices
      GM.observe(fleet_size: 60, duration_seconds: 3)
      GM.enforce(fleet_size: 60, duration_seconds: 3)
      GM.compare(fleet_size: 60, duration_seconds: 3)
      GM.verify()                  # research-derived O3/O4 pair
      GM.verify(Goatmire.Rules.clean_set())
      GM.diagnose()                # bounded BeamLens stage analysis
      GM.thing("agv-1")            # engine-observed properties

    In a release shell use Goatmire.Console directly if the GM alias is absent.
    """)

    :ok
  end

  @doc "Returns engine, fleet, verifier and diagnostic-provider status."
  @spec status() :: map()
  def status do
    %{
      engine: Engine.status(),
      fleet_devices: Fleet.count(),
      maude: Gate.health(),
      diagnostics: Provider.status()
    }
  end

  @doc "Returns the bounded one-minute diagnostic snapshot."
  @spec snapshot() :: map()
  def snapshot, do: Snapshot.read(:one_minute)

  @doc "Stops local devices, undeploys rules, and clears engine runtime state."
  @spec reset() :: :ok
  def reset do
    :ok = Fleet.stop_all()
    :ok = Engine.undeploy()
    Engine.reset()
  end

  @doc "Starts `count` supervised local simulated devices."
  @spec start_fleet(non_neg_integer(), keyword()) :: {:ok, non_neg_integer()}
  def start_fleet(count, opts \\ []), do: Fleet.start_simulated_fleet(count, opts)

  @doc "Runs the storm in observe-only mode."
  @spec observe(keyword()) :: {:ok, Storm.summary()}
  def observe(opts \\ []), do: Storm.run(Keyword.put(opts, :mode, :observe))

  @doc "Runs the storm with enforcement enabled."
  @spec enforce(keyword()) :: {:ok, Storm.summary()}
  def enforce(opts \\ []), do: Storm.run(Keyword.put(opts, :mode, :enforce))

  @doc "Runs the identical-seed observe/enforce comparison."
  @spec compare(keyword()) :: {:ok, map()}
  def compare(opts \\ []), do: Storm.compare(opts)

  @doc "Verifies a rule set, defaulting to the research-derived O3/O4 pair."
  @spec verify([Rules.rule()]) :: {:ok, Goatmire.Verifier.Verdict.t(), Goatmire.Gate.stats()}
  def verify(rules \\ Rules.research_state_conflict_pair()) do
    Gate.verify_partitioned(rules, scenario: :iex)
  end

  @doc "Runs one bounded diagnostic analysis from the current snapshot."
  @spec diagnose(String.t()) :: {:ok, map()} | {:error, Analysis.error_reason()}
  def diagnose(question \\ @default_question), do: Analysis.run(question)

  @doc "Returns the engine's observed properties for one Thing."
  @spec thing(String.t()) :: map()
  def thing(thing_id), do: Engine.properties(thing_id)
end
