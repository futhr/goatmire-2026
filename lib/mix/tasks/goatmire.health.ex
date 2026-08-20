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

  alias Goatmire.{Config, Diagnostics.Provider, Engine, Fleet, Gate, Transport.MQTT}

  @shortdoc "Check Maude, transport, fleet, engine, and the diagnostic reasoners"
  @requirements ["app.start"]

  @impl Mix.Task
  def run(_) do
    maude = Gate.health()
    diagnostics = Provider.preflight()

    report_maude(maude)
    report_transport()
    report_fleet()
    report_engine()
    report_diagnostics(diagnostics)

    case {maude, diagnostics.available} do
      {{:ok, _}, true} -> :ok
      _ -> exit({:shutdown, 1})
    end
  end

  defp report_maude({:ok, version}) do
    ok("maude       #{version}")
  end

  defp report_maude({:error, reason}) do
    fail("maude       unreachable — #{inspect(reason)}")

    Mix.shell().info("""

    Every verification will return :unverified until an interpreter is
    available. Install Maude and put it on PATH, or set :maude_path.
    See docs/maude-for-dummies.md.
    """)
  end

  defp report_transport do
    transport = Config.transport()

    if transport == MQTT do
      mqtt = MQTT.config()
      ok("transport   MQTT → #{mqtt[:host]}:#{mqtt[:port]} as #{mqtt[:client_id]}")
    else
      ok("transport   local (in-BEAM, no broker)")
    end
  end

  defp report_fleet do
    case Fleet.count() do
      0 -> note("fleet       no devices attached")
      n -> ok("fleet       #{n} device(s)")
    end
  end

  defp report_engine do
    status = Engine.status()

    note(
      "engine      #{status.deployed_count} rule(s) deployed, " <>
        "#{length(status.withheld)} withheld, " <>
        "#{status.counters.events} event(s) seen"
    )
  end

  defp report_diagnostics(%{codex: codex, ollama: ollama}) do
    case codex do
      {:ok, %{plan_type: plan_type, quota: quota}} ->
        ok("codex       ChatGPT #{plan_type} plan · #{quota.used_percent || 0}% used")

      {:error, reason} ->
        note("codex       unavailable — #{diagnostic_reason(reason)}")
    end

    case ollama do
      {:ok, %{model: model}} -> ok("ollama      #{model} ready")
      {:error, reason} -> note("ollama      unavailable — #{diagnostic_reason(reason)}")
    end
  end

  defp diagnostic_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp diagnostic_reason(reason), do: inspect(reason, limit: 5, printable_limit: 200)

  defp ok(message), do: Mix.shell().info(IO.ANSI.green() <> "OK   " <> message <> IO.ANSI.reset())
  defp note(message), do: Mix.shell().info("     " <> message)

  defp fail(message),
    do: Mix.shell().error(IO.ANSI.red() <> "FAIL " <> message <> IO.ANSI.reset())
end
