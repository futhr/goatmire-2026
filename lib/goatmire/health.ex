defmodule Goatmire.Health do
  @moduledoc "Readiness facts from the running application, including a broker connection probe."
  alias Goatmire.{Config, Engine, Fleet, Gate, Transport.MQTT}

  @doc "Returns bounded checks without starting another application or model turn."
  @spec snapshot() :: map()
  def snapshot do
    case Goatmire.Deadline.run(&read_snapshot/0, 4_000) do
      {:ok, snapshot} ->
        snapshot

      {:error, _} ->
        %{
          maude: %{status: "unavailable", detail: "application starting or unavailable"},
          transport: inspect(Config.transport()),
          transport_status: "unavailable",
          fleet: %{devices: 0},
          engine: %{available: false}
        }
    end
  end

  defp read_snapshot do
    maude =
      case Goatmire.Deadline.run(&Gate.health/0, 2_000) do
        {:ok, {:ok, version}} -> %{status: "ok", detail: version}
        _ -> %{status: "unavailable", detail: "interpreter check failed"}
      end

    engine = Engine.status()

    %{
      maude: maude,
      transport: inspect(Config.transport()),
      transport_status: transport_status(),
      fleet: %{devices: Fleet.count()},
      engine: %{
        available: true,
        deployed_rules: engine.deployed_count,
        withheld_rules: length(engine.withheld),
        things_seen: engine.things_seen,
        counters: engine.counters
      }
    }
  end

  @doc "Whether the interpreter and the configured transport are ready."
  @spec ready?(map()) :: boolean()
  def ready?(snapshot),
    do:
      snapshot.maude.status == "ok" and snapshot.transport_status == "ok" and
        snapshot.engine[:available] == true

  defp transport_status do
    if Config.transport() == MQTT do
      case Goatmire.Deadline.run(&mqtt_connection/0, 1_500) do
        {:ok, {:ok, _}} -> "ok"
        _ -> "unavailable"
      end
    else
      "ok"
    end
  end

  defp mqtt_connection do
    Tortoise311.Connection.connection(MQTT.config()[:client_id], timeout: 1_000)
  end
end
