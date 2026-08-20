defmodule Goatmire.Diagnostics.BeamlensSupervisor do
  @moduledoc """
  Bounded BeamLens supervision for the stage diagnostic path.

  BeamLens 0.3.1 documents `:skills` and `:max_iterations` on `run/2`, but its
  static coordinator and operators are built once and do not apply those
  per-invocation options. Its top-level supervisor also does not forward a
  custom skill's iteration options to the static operator. This supervisor
  composes BeamLens's public building blocks directly so both limits are real
  process state rather than ignored call-site decoration.

  It intentionally uses the standard `Beamlens.Supervisor` process name and
  standard child IDs, preserving `beamlens_web`'s start/stop controls.
  """

  use Supervisor

  alias Goatmire.Diagnostics.Skill

  @max_iterations 6

  @doc "Starts the bounded BeamLens coordinator and operator tree."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: Beamlens.Supervisor)
  end

  @doc "Maximum reasoning turns permitted for one BeamLens analysis."
  @spec max_iterations() :: pos_integer()
  def max_iterations, do: @max_iterations

  @doc "Cancels an in-flight stage diagnosis and restores idle bounded agents."
  @spec reset() :: :ok
  def reset do
    supervisor = Beamlens.Supervisor

    Enum.each([Beamlens.Coordinator, Beamlens.Operator.Supervisor], fn child_id ->
      case Supervisor.terminate_child(supervisor, child_id) do
        :ok -> :ok
        {:error, :not_found} -> :ok
      end
    end)

    Enum.each([Beamlens.Operator.Supervisor, Beamlens.Coordinator], fn child_id ->
      case Supervisor.restart_child(supervisor, child_id) do
        {:ok, _} -> :ok
        {:ok, _, _} -> :ok
        {:error, :running} -> :ok
      end
    end)

    :ok
  end

  @impl true
  def init(opts) do
    client_registry = Keyword.fetch!(opts, :client_registry)
    :persistent_term.put({Beamlens.Supervisor, :skills}, [Skill])

    children = [
      {Task.Supervisor, name: Beamlens.TaskSupervisor},
      {Registry, keys: :unique, name: Beamlens.OperatorRegistry},
      Beamlens.Skill.Logger.LogStore,
      {Beamlens.Coordinator,
       name: Beamlens.Coordinator,
       skills: [Skill],
       max_iterations: @max_iterations,
       client_registry: client_registry},
      {Beamlens.Operator.Supervisor,
       skills: [[skill: Skill, max_iterations: @max_iterations]], client_registry: client_registry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
