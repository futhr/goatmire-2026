defmodule Mix.Tasks.Goatmire.Ai do
  @moduledoc """
  Ask a local model for a rule set, then check it.

      mix goatmire.ai "reassign a robot whose task overruns by 2x, if ops approves"
      mix goatmire.ai "..." --attempts 3 --tenant acme

  `--attempts` caps the generate→verify rounds (default 2); `--tenant` sets
  the agent id's tenant segment.

  Prints each pass: the rules the model emitted, what `ExMaude.AI` said about
  them, and — if it found something — the revised set and the second verdict.

  Uses the endpoint and model in `config/config.exs`. Model or transport
  failure remains visible; this task never substitutes a recorded response.
  """
  use Mix.Task

  alias Goatmire.AI.RuleGenerator

  @shortdoc "Generate rules with a local model and verify them"
  @requirements ["app.start"]

  @switches [attempts: :integer, tenant: :string]

  @default_prompt "If a robot's task takes more than twice its expected duration, " <>
                    "reassign it to the nearest available robot. Only proceed with the " <>
                    "reassignment if ops approves."

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} = OptionParser.parse(args, strict: @switches)

    invalid != [] and Mix.raise("unknown options: #{inspect(invalid)}")

    prompt = Enum.join(positional, " ")
    prompt = if prompt == "", do: @default_prompt, else: prompt

    generator_opts =
      [max_attempts: opts[:attempts] || 2]
      |> then(&if opts[:tenant], do: Keyword.put(&1, :tenant, opts[:tenant]), else: &1)

    Mix.shell().info(IO.ANSI.bright() <> "> " <> prompt <> IO.ANSI.reset())

    case RuleGenerator.run(prompt, generator_opts) do
      {:ok, transcript} -> print(transcript)
      {:error, reason} -> abort(reason)
    end
  end

  defp print(%{passes: passes, final_status: final}) do
    Enum.each(passes, &print_pass/1)

    colour = if final == :clean, do: IO.ANSI.green(), else: IO.ANSI.red()
    Mix.shell().info("\n#{colour}final: #{final}#{IO.ANSI.reset()}")

    Mix.shell().info("""

    A clean second pass means the revision contains no conflict of the seven
    types ExMaude.AI models. It says nothing about the model that wrote it, and
    it is not a reason to deploy generated rules without a human.
    """)
  end

  defp print_pass(pass) do
    Mix.shell().info("\n  pass #{pass.attempt} — #{pass.status} (#{pass.duration_us} µs)")

    Enum.each(pass.rules, fn rule ->
      Mix.shell().info("    rule #{rule.id}: #{length(rule.invocations)} invocation(s)")
    end)

    Enum.each(pass.conflicts, fn conflict ->
      Mix.shell().info(
        IO.ANSI.red() <>
          "    ✗ #{conflict[:type]} #{inspect(conflict[:rule1])}: #{conflict[:reason]}" <>
          IO.ANSI.reset()
      )
    end)
  end

  defp abort({:llm_unreachable, reason}) do
    Mix.shell().error("""
    Could not reach the model: #{inspect(reason)}

    Check the local model settings in config/config.exs. The command does not
    substitute a recorded response.
    """)

    exit({:shutdown, 1})
  end

  defp abort(reason) do
    Mix.shell().error("FAIL — #{inspect(reason)}")
    exit({:shutdown, 1})
  end
end
