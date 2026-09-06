defmodule Mix.Tasks.Goatmire.Health do
  @moduledoc """
  Pre-talk readiness check.

  Independent facts, reported separately because they fail separately: the
  Maude interpreter, transport, fleet, engine, ChatGPT-plan Codex access, and
  the Ollama fallback. Exits non-zero if Maude is unreachable or neither
  diagnostic reasoner is available.

      mix goatmire.health
  """

  use Mix.Task

  alias Goatmire.Diagnostics.Provider
  alias Goatmire.Transport.MQTT

  @shortdoc "Check the running stage server, or an isolated readiness process"
  @requirements ["compile"]

  @impl Mix.Task
  def run(_) do
    snapshot = running_snapshot()
    Enum.each(snapshot, fn {key, value} -> Mix.shell().info("#{key}  #{inspect(value)}") end)
    diagnostics = Provider.preflight()
    Mix.shell().info("codex  #{availability(diagnostics.codex)}")
    Mix.shell().info("ollama #{availability(diagnostics.ollama)}")

    unless snapshot["maude"]["status"] == "ok" and snapshot["transport_status"] == "ok" and
             snapshot["engine"]["available"] == true and
             diagnostics.available do
      exit({:shutdown, 1})
    end

    :ok
  end

  defp running_snapshot do
    if Process.whereis(Goatmire.Supervisor) do
      Goatmire.Health.snapshot()
      |> Jason.encode!()
      |> Jason.decode!()
    else
      {:ok, _} = Application.ensure_all_started(:req)

      case Req.get("http://127.0.0.1:4000/api/health",
             retry: false,
             receive_timeout: 5_000,
             connect_options: [timeout: 1_000]
           ) do
        {:ok, %{body: %{"maude" => _, "transport_status" => _} = snapshot}} -> snapshot
        _ -> isolated_snapshot()
      end
    end
  end

  defp isolated_snapshot do
    Mix.shell().info(
      "No stage server found; checking an isolated node with a unique MQTT client ID."
    )

    for {key, value} <- [
          role: :notebook,
          metrics_enabled: false,
          autostart_fleet: false,
          real_devices: [],
          modbus_sensors: [],
          vda5050_enabled: false
        ] do
      Application.put_env(:goatmire, key, value)
    end

    mqtt =
      MQTT.config()
      |> Keyword.update!(
        :client_id,
        &(&1 <> "-health-" <> Integer.to_string(System.unique_integer([:positive])))
      )

    Application.put_env(:goatmire, :mqtt, mqtt)

    case Application.ensure_all_started(:goatmire) do
      {:ok, _} ->
        Goatmire.Health.snapshot()
        |> Jason.encode!()
        |> Jason.decode!()

      {:error, _} ->
        Mix.raise("readiness process could not start; check the broker and interpreter")
    end
  end

  defp availability({:ok, _}), do: "ready"
  defp availability({:error, reason}), do: "unavailable: #{inspect(reason, limit: 3)}"
end
