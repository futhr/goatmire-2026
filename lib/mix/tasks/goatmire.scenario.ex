defmodule Mix.Tasks.Goatmire.Scenario do
  @moduledoc """
  Run one of the five beats from the CLI.

      mix goatmire.scenario 1                       # state conflict
      mix goatmire.scenario 2 --fleet 60 --duration 30
      mix goatmire.scenario 3                       # clean rule set
      mix goatmire.scenario 4 --prompt "..."        # generated rules
      mix goatmire.scenario 5                       # agent policy, by hand

  Scenario 2 runs the shift change twice by default — observe-only, then
  enforced — and prints both measured results plus the ratio between them.
  `--mode observe` or `--mode enforce` runs one half. `--tick` sets the
  device physics interval in milliseconds; lower means denser telemetry.
  """
  use Mix.Task

  @shortdoc "Run a Goatmire scenario (1..5), entirely locally"
  @requirements ["app.start"]

  @switches [
    fleet: :integer,
    duration: :integer,
    tick: :integer,
    mode: :string,
    prompt: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} = OptionParser.parse(args, strict: @switches)

    invalid != [] and
      Mix.raise("unknown options: #{inspect(invalid)} — see `mix help goatmire.scenario`")

    case positional do
      [value] ->
        value
        |> parse_number()
        |> dispatch(runner_opts(opts))

      [] ->
        Mix.raise("scenario number required — `mix goatmire.scenario <1..5>`")

      _ ->
        Mix.raise("expected exactly one scenario number")
    end
  end

  defp parse_number(value) do
    case Integer.parse(value) do
      {number, ""} when number in 1..5 -> number
      _ -> Mix.raise("scenario number must be 1..5, got #{inspect(value)}")
    end
  end

  defp runner_opts(opts) do
    []
    |> put(:fleet_size, opts[:fleet])
    |> put(:duration_seconds, opts[:duration])
    |> put(:tick_ms, opts[:tick])
    |> put(:prompt, opts[:prompt])
    |> put(:mode, parse_mode(opts[:mode]))
  end

  defp put(opts, _, nil), do: opts
  defp put(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_mode(nil), do: nil
  defp parse_mode("observe"), do: :observe
  defp parse_mode("enforce"), do: :enforce

  defp parse_mode(other),
    do: Mix.raise("--mode must be observe or enforce, got #{inspect(other)}")

  defp dispatch(number, opts) do
    Mix.shell().info(IO.ANSI.bright() <> "Scenario #{number}" <> IO.ANSI.reset())

    case Goatmire.ScenarioRunner.run(number, opts) do
      {:ok, result} ->
        print(number, result)

      {:error, reason} ->
        Mix.shell().error(IO.ANSI.red() <> "FAIL — #{inspect(reason)}" <> IO.ANSI.reset())
        exit({:shutdown, 1})
    end
  end

  defp print(2, %{observed: observed, enforced: enforced, ratio: ratio}) do
    Mix.shell().info("""

      observe    #{observed.alerts} alerts from #{observed.events} events \
    (#{observed.rules_deployed} rules deployed)
      enforce    #{enforced.alerts} alerts from #{enforced.events} events \
    (#{enforced.rules_deployed} deployed, #{length(enforced.rules_withheld)} withheld)
      ratio      #{if ratio, do: "#{ratio}×", else: "n/a"}

    Measured on this machine at this fleet size and tick rate. Read these
    numbers on the day; do not quote them from a previous run.
    """)
  end

  defp print(2, %{mode: mode} = summary) do
    Mix.shell().info("""

      #{mode}    #{summary.alerts} alerts from #{summary.events} events
                 #{summary.rules_deployed} rules deployed, \
    #{length(summary.rules_withheld)} withheld, verdict #{summary.verdict.status}

    Measured on this machine at this fleet size and tick rate. Compare this
    with the other mode from the same checkout; do not quote an earlier run.
    """)
  end

  defp print(4, %{passes: passes, final_status: final}) do
    Enum.each(passes, fn pass ->
      Mix.shell().info(
        "  pass #{pass.attempt}: #{pass.status} " <>
          "(#{length(pass.rules)} rules, #{length(pass.conflicts)} conflicts, #{pass.duration_us} µs)"
      )

      Enum.each(pass.conflicts, fn conflict ->
        Mix.shell().info("    → #{conflict[:type]} #{inspect(conflict[:rule1])}")
      end)
    end)

    Mix.shell().info("  final: #{final}")
  end

  defp print(_, %{verdict: verdict}) do
    Mix.shell().info(
      "  #{verdict.status} — #{verdict.rule_count} rules, #{verdict.duration_us} µs"
    )

    Enum.each(verdict.conflicts, fn conflict ->
      Mix.shell().info("    → #{conflict[:type]}: #{conflict[:reason]}")
    end)

    Mix.shell().info("  scope: #{verdict.scope}")
  end

  defp print(_, result), do: Mix.shell().info("  #{inspect(result, pretty: true)}")
end
