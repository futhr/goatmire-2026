defmodule Goatmire.Engine.Supervisor do
  @moduledoc """
  Verifier pool and rule engine under `rest_for_one`: a pool restart takes
  the engine with it, so the engine never holds verdicts from a pool
  generation it did not observe.
  """

  use Supervisor

  alias Goatmire.Config

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

  # Preload into every worker at start. Otherwise the first reduction broadcasts
  # a load into workers that may be busy, and concurrent verifications race.
  defp preload_maude_templates do
    Application.put_env(:ex_maude, :preload_modules, [
      ExMaude.iot_rules_path(),
      ExMaude.ai_rules_path()
    ])
  end

  defp ex_maude_children do
    case ExMaude.Binary.find() do
      nil -> []
      _ -> [ex_maude_child_spec()]
    end
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
