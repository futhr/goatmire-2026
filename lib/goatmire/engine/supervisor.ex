defmodule Goatmire.Engine.Supervisor do
  @moduledoc """
  Verifier pool and rule engine under `rest_for_one`: a pool restart takes
  the engine with it, so the engine never holds verdicts from a pool
  generation it did not observe.

  The pool joins the tree only when an interpreter is present *and* able to
  load the bundled models. A broken installation therefore degrades every
  verdict to `:unverified` instead of stopping the application, and the check
  runs again on each restart of this branch.
  """

  use Supervisor

  require Logger

  alias Goatmire.Config

  @probe_timeout_ms 10_000

  @doc "Starts the verifier pool, rule engine, and optional VDA 5050 bridge."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = ex_maude_children() ++ [Goatmire.Engine] ++ vda5050_children()

    Supervisor.init(children, strategy: :rest_for_one, max_restarts: 10, max_seconds: 10)
  end

  defp vda5050_children do
    if Config.vda5050_enabled?(), do: [Goatmire.Protocol.VDA5050.Bridge], else: []
  end

  @doc """
  Whether an interpreter is present and can load the bundled Maude models.

  A binary alone is not enough: one that cannot load its own prelude answers
  `maude --version` and then fails as the pool starts its workers, which would
  take the whole application down with it. Probing a single throwaway worker
  first keeps such an installation out of the tree, so the dashboard still runs
  and the gate reports `:unverified`.
  """
  @spec interpreter_ready?() :: boolean()
  def interpreter_ready? do
    not is_nil(ExMaude.Binary.find()) and preloads_usable?()
  end

  defp preloads_usable? do
    owner = self()
    token = make_ref()
    {probe, monitor} = spawn_monitor(fn -> send(owner, {token, probe_worker()}) end)

    receive do
      {^token, :ok} ->
        Process.demonitor(monitor, [:flush])
        true

      {^token, {:error, reason}} ->
        Process.demonitor(monitor, [:flush])
        unusable(reason)

      {:DOWN, ^monitor, :process, ^probe, reason} ->
        unusable(reason)
    after
      @probe_timeout_ms ->
        Process.exit(probe, :kill)
        Process.demonitor(monitor, [:flush])
        unusable(:timeout)
    end
  end

  # Runs in a throwaway process: the worker is linked to that process, so a
  # failure during startup never reaches the supervisor.
  defp probe_worker do
    Process.flag(:trap_exit, true)

    case ExMaude.Backend.impl().start_link(preload_modules: preload_paths()) do
      {:ok, worker} ->
        Process.exit(worker, :shutdown)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp unusable(reason) do
    Logger.warning(
      "maude interpreter found but unusable (#{inspect(reason, limit: 5)}); " <>
        "verification will report :unverified"
    )

    false
  end

  defp preload_paths, do: [ExMaude.iot_rules_path(), ExMaude.ai_rules_path()]

  # Preload into every worker at start. Otherwise the first reduction broadcasts
  # a load into workers that may be busy, and concurrent verifications race.
  defp preload_maude_templates do
    Application.put_env(:ex_maude, :preload_modules, preload_paths())
  end

  defp ex_maude_children do
    if interpreter_ready?(), do: [ex_maude_child_spec()], else: []
  end

  defp ex_maude_child_spec do
    preload_maude_templates()

    :erlang.apply(ExMaude.Pool, :child_spec, [[pool_size: 4, pool_max_overflow: 0]])
    |> normalize_child_spec()
  end

  defp normalize_child_spec(%{} = child_spec), do: child_spec

  defp normalize_child_spec({id, start, restart, shutdown, type, modules}) do
    %{id: id, start: start, restart: restart, shutdown: shutdown, type: type, modules: modules}
  end
end
