defmodule Mix.Tasks.Goatmire.Benchmark do
  @moduledoc """
  Record reproducible partitioned-verification measurements as JSON.

      mix goatmire.benchmark
      mix goatmire.benchmark --runs 10 --output tmp/final-rehearsal.json

  The artifact includes the commit, machine, rule and partition counts,
  individual durations, median, p95, verdict, and skipped/considered pairs.
  It is the source for talk timings; no slide should contain a hand-written
  performance number.
  """

  use Mix.Task

  @child_env [
    {"ANTHROPIC_API_KEY", nil},
    {"GITHUB_TOKEN", nil},
    {"GH_TOKEN", nil},
    {"OPENAI_API_KEY", nil},
    {"SSH_AUTH_SOCK", nil}
  ]

  alias Goatmire.{Gate, Rules}

  @shortdoc "Record labelled gate measurements for the talk"
  @requirements ["compile"]
  @switches [runs: :integer, output: :string]

  @impl Mix.Task
  def run(args) do
    start_verifier()

    {opts, _, invalid} = OptionParser.parse(args, strict: @switches)
    invalid != [] and Mix.raise("unknown options: #{inspect(invalid)}")

    runs = max(opts[:runs] || 5, 1)
    output = opts[:output] || "tmp/goatmire-benchmark.json"

    cases = [
      {"research_pair", Rules.research_state_conflict_pair()},
      {"fleet_40_rules", Rules.fleet(20)},
      {"fleet_400_rules", Rules.fleet(200)},
      {"fleet_2000_rules", Rules.fleet(1_000)}
    ]

    measurements = Enum.map(cases, fn {name, rules} -> measure(name, rules, runs) end)

    artifact = %{
      schema_version: 2,
      interpreter: interpreter(),
      model_sha256: model_hashes(),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      commit: git_commit(),
      dirty: git_dirty?(),
      runtime: %{
        elixir: System.version(),
        otp: otp_version(),
        architecture: to_string(:erlang.system_info(:system_architecture)),
        os: :os.type() |> inspect(),
        schedulers: :erlang.system_info(:schedulers_online)
      },
      warmup_runs: 1,
      measured_runs: runs,
      cases: measurements
    }

    File.mkdir_p!(Path.dirname(output))
    File.write!(output, Jason.encode!(artifact, pretty: true) <> "\n")
    Mix.shell().info("wrote #{output}")

    Enum.each(measurements, fn result ->
      Mix.shell().info(
        "#{result.name}: #{result.rule_count} rules · #{result.stats.partitions} partitions · " <>
          "median #{result.median_us} µs · p95 #{result.p95_us} µs · #{result.status}"
      )
    end)
  end

  defp start_verifier do
    unless Process.whereis(Goatmire.Supervisor) do
      for {key, value} <- [
            role: :notebook,
            transport: Goatmire.Transport.Local,
            metrics_enabled: false,
            vda5050_enabled: false
          ] do
        Application.put_env(:goatmire, key, value)
      end

      {:ok, _} = Application.ensure_all_started(:goatmire)
    end
  end

  defp measure(name, rules, runs) do
    {:ok, _, _} = Gate.verify_partitioned(rules, scenario: {:benchmark_warmup, name})

    results =
      Enum.map(1..runs, fn _ ->
        {:ok, verdict, stats} = Gate.verify_partitioned(rules, scenario: {:benchmark, name})

        %{
          duration_us: verdict.duration_us,
          status: verdict.status,
          stats: stats,
          reason: inspect(verdict.reason),
          conflicts: Enum.map(verdict.conflicts, &inspect/1),
          scope: verdict.scope
        }
      end)

    durations =
      results
      |> Enum.map(& &1.duration_us)
      |> Enum.sort()

    statuses = Enum.uniq_by(results, & &1.status)
    status = if length(statuses) == 1, do: hd(results).status, else: :mixed

    %{
      name: name,
      rule_count: length(rules),
      status: status,
      valid_measurement: Enum.all?(results, &(&1.status in [:clean, :conflicts])),
      stats: hd(results).stats,
      runs: results,
      corpus_sha256: digest(:erlang.term_to_binary(rules, [:deterministic])),
      durations_us: Enum.map(results, & &1.duration_us),
      median_us: percentile(durations, 0.5),
      p95_us: percentile(durations, 0.95)
    }
  end

  defp interpreter do
    %{
      health: inspect(Gate.health()),
      backend: inspect(Application.get_env(:goatmire, :verifier, Goatmire.Verifier)),
      pool: inspect(ExMaude.Pool.status())
    }
  end

  # Paths come only from the installed dependency directory, never request input.
  defp model_hashes do
    :ex_maude
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("maude/*.maude")
    |> Path.wildcard()
    # credo:disable-for-next-line OeditusCredo.Check.Security.PathTraversal
    |> Map.new(fn path -> {Path.basename(path), digest(File.read!(path))} end)
  end

  defp digest(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)

  # OTP provides both path components; no caller can choose a file.
  defp otp_version do
    path =
      Path.join([
        to_string(:code.root_dir()),
        "releases",
        to_string(:erlang.system_info(:otp_release)),
        "OTP_VERSION"
      ])

    # credo:disable-for-next-line OeditusCredo.Check.Security.PathTraversal
    case File.read(path) do
      {:ok, version} -> String.trim(version)
      _ -> to_string(:erlang.system_info(:otp_release))
    end
  end

  defp percentile(sorted, fraction) do
    index = ceil(length(sorted) * fraction) - 1
    Enum.at(sorted, max(index, 0))
  end

  defp git_commit do
    case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true, env: @child_env) do
      {commit, 0} -> String.trim(commit)
      _ -> "unknown"
    end
  end

  defp git_dirty? do
    case System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true, env: @child_env) do
      {"", 0} -> false
      {_, 0} -> true
      _ -> nil
    end
  end
end
