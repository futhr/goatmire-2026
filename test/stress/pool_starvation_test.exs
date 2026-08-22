defmodule Goatmire.PoolStarvationTest do
  @moduledoc """
  Slide 13 as a test: with the four-worker pool saturated far past capacity,
  every verification must end in a verdict — `:unverified` included — and
  never a hang, a raise, or an engine stall.
  """

  use ExUnit.Case, async: false

  alias Goatmire.{Rules, Verifier}

  @moduletag :stress
  @moduletag :maude
  @moduletag timeout: 300_000

  test "saturating the pool yields verdicts, never hangs, and the pool drains" do
    results =
      1..96
      |> Task.async_stream(
        fn n ->
          rules =
            case rem(n, 3) do
              0 -> Rules.clean_set()
              1 -> Rules.state_conflict_pair()
              2 -> Rules.research_state_conflict_pair()
            end

          Verifier.verify_partitioned(rules, scenario: {:starvation, n})
        end,
        max_concurrency: 48,
        ordered: false,
        timeout: 120_000
      )
      |> Enum.to_list()

    assert length(results) == 96

    statuses =
      Enum.map(results, fn result ->
        assert {:ok, {:ok, %{status: status}, _}} = result
        assert status in [:clean, :conflicts, :unverified]
        status
      end)

    # Starvation may produce honest :unverified verdicts; it must still decide
    # most of the load.
    decided = Enum.count(statuses, &(&1 in [:clean, :conflicts]))
    assert decided > 48

    assert_eventually(fn -> ExMaude.Pool.status().in_use == 0 end)
  end

  test "the engine answers within a second while the pool is saturated" do
    saturation =
      Task.async(fn ->
        1..32
        |> Task.async_stream(
          fn n -> Verifier.verify_partitioned(Rules.clean_set(), scenario: {:starvation_bg, n}) end,
          max_concurrency: 32,
          ordered: false,
          timeout: 120_000
        )
        |> Stream.run()
      end)

    Enum.each(1..10, fn _ ->
      {elapsed_us, status} = :timer.tc(fn -> Goatmire.Engine.status() end)
      assert is_map(status)
      assert elapsed_us < 1_000_000
      Process.sleep(100)
    end)

    Task.await(saturation, 240_000)
  end

  defp assert_eventually(fun, timeout_ms \\ 30_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    eventually(fun, deadline)
  end

  defp eventually(fun, deadline) do
    cond do
      fun.() ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        assert fun.()

      true ->
        Process.sleep(50)
        eventually(fun, deadline)
    end
  end
end
