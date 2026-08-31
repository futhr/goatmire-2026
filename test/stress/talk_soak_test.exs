defmodule Goatmire.TalkSoakTest do
  @moduledoc """
  Talk-length wear test: repeated event storms, fleet churn, verifications,
  and slide navigation must not leak memory or processes. Excluded by
  default; run with `mix test.soak` (SOAK_ITERATIONS overrides the length).
  """

  use ExUnit.Case, async: false

  alias Goatmire.{Engine, Fleet, Gate, Rules, StubVerifier, Transport}
  alias Goatmire.Talk.Clock

  @moduletag :soak
  @moduletag timeout: 3_600_000

  setup do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    Fleet.stop_all()
    :ok = Engine.undeploy()
    :ok = Engine.reset()
    Clock.reset()

    on_exit(fn ->
      Fleet.stop_all()
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
      Clock.reset()
    end)

    :ok
  end

  test "repeated demo cycles hold memory and process count flat" do
    iterations = String.to_integer(System.get_env("SOAK_ITERATIONS", "20"))
    warmup = min(5, iterations)

    baseline =
      Enum.reduce(1..iterations, nil, fn iteration, baseline ->
        cycle(iteration)

        cond do
          iteration == warmup -> measure()
          iteration == iterations -> check(baseline)
          true -> baseline
        end
      end)

    assert baseline != nil
  end

  defp cycle(iteration) do
    Enum.each(1..2_000, fn n ->
      :ok = Transport.publish_telemetry("soak-#{rem(n, 40)}", "reading", n)
    end)

    if rem(iteration, 2) == 0 do
      {:ok, _} = Fleet.start_simulated_fleet(300, tick_ms: 0)
    else
      Fleet.stop_all()
    end

    Enum.each(1..10, fn _ ->
      {:ok, _} = Gate.verify(Rules.clean_set(), scenario: :soak)
    end)

    Clock.goto(rem(iteration, 18) + 1)
    drain(Engine)
  end

  defp check(baseline) do
    Fleet.stop_all()
    drain(Engine)
    :erlang.garbage_collect()
    %{memory: memory, processes: processes} = measure()

    assert memory < baseline.memory * 1.25,
           "memory grew from #{baseline.memory} to #{memory} bytes over the soak"

    assert processes < baseline.processes + 200,
           "process count grew from #{baseline.processes} to #{processes} over the soak"

    assert {:message_queue_len, 0} = Process.info(Process.whereis(Engine), :message_queue_len)
    baseline
  end

  defp measure do
    %{memory: :erlang.memory(:total), processes: :erlang.system_info(:process_count)}
  end

  defp drain(name) do
    deadline = System.monotonic_time(:millisecond) + 30_000
    drain(name, deadline)
  end

  defp drain(name, deadline) do
    {:message_queue_len, len} = Process.info(Process.whereis(name), :message_queue_len)

    cond do
      len == 0 ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        :ok

      true ->
        Process.sleep(25)
        drain(name, deadline)
    end
  end
end
