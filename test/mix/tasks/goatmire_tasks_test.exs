defmodule Goatmire.MixTasksTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Goatmire.AI.RuleGenerator
  alias Goatmire.{Engine, Fleet, StubVerifier}
  alias Mix.Tasks.Goatmire.{Ai, Benchmark, Health, Scenario, Storm}

  setup do
    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    Application.put_env(:goatmire, :verifier, StubVerifier)
    Application.put_env(:goatmire, :diagnostics_codex_runner, Goatmire.FakeCodexRunner)
    Application.put_env(:goatmire, :diagnostics_ollama_runner, Goatmire.FakeOllamaRunner)
    StubVerifier.reset()
    Fleet.stop_all()
    :ok = Engine.undeploy()

    on_exit(fn ->
      Mix.shell(previous_shell)
      Application.delete_env(:goatmire, :verifier)
      Application.delete_env(:goatmire, :diagnostics_codex_runner)
      Application.delete_env(:goatmire, :diagnostics_ollama_runner)
      Fleet.stop_all()
    end)

    :ok
  end

  describe "goatmire.storm" do
    test "runs a short measured mode and prints its admission result" do
      StubVerifier.set(:clean)

      Storm.run([
        "--mode",
        "observe",
        "--fleet",
        "1",
        "--duration",
        "1",
        "--tick",
        "20"
      ])

      messages = drain_shell()
      assert Enum.any?(messages, &(&1 =~ "observe"))
      assert Enum.any?(messages, &(&1 =~ "alerts"))
      assert Enum.any?(messages, &(&1 =~ "rules deployed"))
      assert Enum.any?(messages, &(&1 =~ "verdict clean"))
    end

    test "rejects malformed switches and modes" do
      assert_raise Mix.Error, ~r/unknown options/, fn -> Storm.run(["--wat"]) end

      assert_raise Mix.Error, ~r/mode must be observe or enforce/, fn ->
        Storm.run(["--mode", "turbo"])
      end
    end
  end

  describe "goatmire.ai" do
    test "prints a checked pass from the configured model boundary" do
      StubVerifier.set(:clean)
      Req.Test.verify_on_exit!()

      Req.Test.expect(RuleGenerator, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  ~s({"rules":[{"id":"r1","agent":"ops","trigger":{"type":"always"},"invocations":[]}]})
              }
            }
          ]
        })
      end)

      Ai.run(["--attempts", "2", "reassign only after approval"])

      messages = drain_shell()
      assert Enum.any?(messages, &(&1 =~ "pass 1"))
      assert Enum.any?(messages, &(&1 =~ "final:"))
      assert Enum.any?(messages, &(&1 =~ "not a reason to deploy"))
    end

    test "rejects the removed fixture switch" do
      assert_raise Mix.Error, ~r/unknown options/, fn -> Ai.run(["--fixture"]) end
    end

    test "rejects unsupported options before contacting a model" do
      assert_raise Mix.Error, ~r/unknown options/, fn -> Ai.run(["--wat"]) end
    end
  end

  describe "goatmire.benchmark" do
    test "writes a machine-labelled artifact with every declared case" do
      output =
        Path.join(
          System.tmp_dir!(),
          "goatmire-benchmark-test-#{System.unique_integer([:positive])}.json"
        )

      on_exit(fn -> File.rm(output) end)
      Benchmark.run(["--runs", "1", "--output", output])

      contents = File.read!(output)
      artifact = Jason.decode!(contents)
      assert artifact["schema_version"] == 1
      assert artifact["measured_runs"] == 1
      assert length(artifact["cases"]) == 4
      assert Enum.all?(artifact["cases"], &(&1["durations_us"] == [42]))
      assert Enum.all?(artifact["cases"], &is_integer(&1["stats"]["partitions"]))
      assert Enum.any?(drain_shell(), &(&1 =~ "fleet_2000_rules"))
    end

    test "rejects unsupported options" do
      assert_raise Mix.Error, ~r/unknown options/, fn -> Benchmark.run(["--wat"]) end
    end
  end

  describe "goatmire.health" do
    test "reports the transport, the fleet, and the engine" do
      # Exits non-zero when no interpreter is reachable and returns :ok when
      # one is. Both are correct; what must hold either way is that all four
      # facts were printed before the decision.
      try do
        Health.run([])
      catch
        :exit, {:shutdown, 1} -> :expected_without_an_interpreter
      end

      messages = drain_shell()
      assert Enum.any?(messages, &(&1 =~ "transport"))
      assert Enum.any?(messages, &(&1 =~ "fleet"))
      assert Enum.any?(messages, &(&1 =~ "engine"))
      assert Enum.any?(messages, &(&1 =~ "maude"))
      assert Enum.any?(messages, &(&1 =~ "codex"))
      assert Enum.any?(messages, &(&1 =~ "ollama"))
    end
  end

  describe "goatmire.scenario" do
    test "rejects a scenario number outside 1..5" do
      assert_raise Mix.Error, ~r/must be 1\.\.5/, fn ->
        Scenario.run(["9"])
      end
    end

    test "rejects a missing scenario number" do
      assert_raise Mix.Error, ~r/scenario number required/, fn ->
        Scenario.run([])
      end
    end

    test "rejects unknown switches" do
      assert_raise Mix.Error, ~r/unknown options/, fn ->
        Scenario.run(["1", "--nonsense", "x"])
      end
    end

    test "scenario 3 prints the verdict and its scope" do
      StubVerifier.set(:clean)
      Scenario.run(["3"])

      messages = drain_shell()
      assert Enum.any?(messages, &(&1 =~ "clean"))
      assert Enum.any?(messages, &(&1 =~ "scope:"))
    end

    test "scenario 2 single-mode output includes the measured storm counters" do
      StubVerifier.set(:clean)

      Scenario.run([
        "2",
        "--mode",
        "observe",
        "--fleet",
        "1",
        "--duration",
        "1",
        "--tick",
        "20"
      ])

      messages = drain_shell()
      assert Enum.any?(messages, &(&1 =~ "observe"))
      assert Enum.any?(messages, &(&1 =~ "alerts from"))
      assert Enum.any?(messages, &(&1 =~ "rules deployed"))
      assert Enum.any?(messages, &(&1 =~ "Measured on this machine"))
    end
  end

  defp drain_shell(acc \\ []) do
    receive do
      {:mix_shell, _, [message]} -> drain_shell([message | acc])
    after
      10 -> acc
    end
  end
end
