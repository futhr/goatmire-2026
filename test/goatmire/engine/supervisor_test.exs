defmodule Goatmire.Engine.SupervisorTest do
  @moduledoc false
  # Starts a throwaway interpreter worker and takes the shared verifier pool
  # down and back up, so it must not run beside other tests.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Goatmire.Engine.Supervisor, as: EngineSupervisor
  alias Goatmire.{Rules, Verifier}

  @pool :ex_maude_pool

  describe "interpreter_ready?/0" do
    test "an interpreter that answers --version but loads nothing is not ready" do
      stub = write_stub_interpreter()
      previous = Application.get_env(:ex_maude, :maude_path)
      Application.put_env(:ex_maude, :maude_path, stub)

      on_exit(fn ->
        if previous,
          do: Application.put_env(:ex_maude, :maude_path, previous),
          else: Application.delete_env(:ex_maude, :maude_path)
      end)

      assert {:ok, "9.9.9"} = ExMaude.version(), "the stub is the interpreter under test"

      log = capture_log(fn -> refute EngineSupervisor.interpreter_ready?() end)

      assert log =~ "unusable"
      assert log =~ ":unverified"
    end

    @tag :maude
    test "the interpreter this suite verifies with is ready" do
      assert EngineSupervisor.interpreter_ready?()
    end
  end

  describe "health without a usable pool" do
    @tag :maude
    test "reports an error rather than a version, and verdicts stay unverified" do
      assert {:ok, _} = Verifier.health()
      :ok = Supervisor.terminate_child(EngineSupervisor, @pool)

      try do
        assert {:error, :verifier_pool_unavailable} = Verifier.health()
        assert {:ok, %{status: :unverified}} = Verifier.verify(Rules.clean_set())
        assert Process.whereis(Goatmire.Engine)
      after
        {:ok, _} = Supervisor.restart_child(EngineSupervisor, @pool)
      end

      assert {:ok, _} = Verifier.health()
      assert {:ok, %{status: :clean}} = Verifier.verify(Rules.clean_set())
    end
  end

  defp write_stub_interpreter do
    directory =
      Path.join(
        System.tmp_dir!(),
        "goatmire-stub-maude-" <> Base.encode16(:crypto.strong_rand_bytes(6))
      )

    File.mkdir!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    stub = Path.join(directory, "maude")

    File.write!(stub, """
    #!/bin/sh
    case "$1" in
      --version) echo "9.9.9"; exit 0 ;;
    esac
    exit 1
    """)

    File.chmod!(stub, 0o700)
    stub
  end
end
