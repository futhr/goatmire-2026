defmodule Mix.Tasks.Goatmire.Storm do
  @moduledoc """
  Run the shift change directly, without the scenario wrapper.

      mix goatmire.storm --fleet 200 --duration 60
      mix goatmire.storm --fleet 200 --duration 60 --mode observe
      mix goatmire.storm --compare
      mix goatmire.storm --fleet 200 --duration 60 --tick 250

  `--tick` is the device physics interval in milliseconds; lower means
  denser telemetry.

  The counters printed are what the engine produced from telemetry that
  crossed the transport during this run. They are the simulator's numbers on
  this machine — not a benchmark, and not an incident.
  """
  use Mix.Task

  alias Goatmire.Scenario.Storm

  @shortdoc "Stage a shift change against the local fleet"
  @requirements ["app.start"]

  @switches [
    fleet: :integer,
    duration: :integer,
    tick: :integer,
    mode: :string,
    compare: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, invalid} = OptionParser.parse(args, strict: @switches)

    invalid != [] and Mix.raise("unknown options: #{inspect(invalid)}")

    storm_opts =
      [
        fleet_size: opts[:fleet] || 200,
        duration_seconds: opts[:duration] || 60,
        tick_ms: opts[:tick] || 250
      ]

    if opts[:compare] do
      {:ok, %{observed: observed, enforced: enforced, ratio: ratio}} = Storm.compare(storm_opts)
      print(observed)
      print(enforced)
      Mix.shell().info("\n  ratio #{if ratio, do: "#{ratio}×", else: "n/a"}")
    else
      mode = parse_mode(opts[:mode] || "enforce")
      {:ok, summary} = Storm.run(Keyword.put(storm_opts, :mode, mode))
      print(summary)
    end
  end

  defp print(summary) do
    colour = if summary.mode == :enforce, do: IO.ANSI.green(), else: IO.ANSI.red()

    Mix.shell().info("""

    #{colour}#{summary.mode}#{IO.ANSI.reset()}  \
    #{summary.alerts} alerts · #{summary.events} events · #{summary.throttled} throttled
              #{summary.rules_deployed} rules deployed, \
    #{length(summary.rules_withheld)} withheld, verdict #{summary.verdict.status}
    """)
  end

  defp parse_mode("observe"), do: :observe
  defp parse_mode("enforce"), do: :enforce

  defp parse_mode(other),
    do: Mix.raise("--mode must be observe or enforce, got #{inspect(other)}")
end
