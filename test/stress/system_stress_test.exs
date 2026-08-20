defmodule Goatmire.SystemStressTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.{Engine, Fleet, Rules, StubVerifier, Transport, Verifier}

  @moduletag :stress
  @moduletag timeout: 180_000

  setup do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    Fleet.stop_all()
    :ok = Engine.undeploy()
    :ok = Engine.reset()

    on_exit(fn ->
      Fleet.stop_all()
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
    end)

    :ok
  end

  test "the engine drains 20,000 concurrent transport events without loss or mailbox failure" do
    producers = 40
    events_per_producer = 500

    1..producers
    |> Task.async_stream(
      fn producer ->
        for event <- 1..events_per_producer do
          thing_id = "stress-#{producer}-#{rem(event, 50)}"
          :ok = Transport.publish_telemetry(thing_id, "reading", event)
        end
      end,
      max_concurrency: producers,
      ordered: false,
      timeout: 60_000
    )
    |> Enum.each(fn result -> assert match?({:ok, _}, result) end)

    expected = producers * events_per_producer
    assert_eventually(fn -> Engine.status().counters.events == expected end, 20_000)

    status = Engine.status()
    assert status.counters == %{events: expected, alerts: 0, throttled: 0}
    assert status.things_seen == producers * 50
    assert Process.alive?(Process.whereis(Engine))
    assert {:message_queue_len, 0} = Process.info(Process.whereis(Engine), :message_queue_len)
  end

  test "fleet snapshots remain bounded while devices churn" do
    assert {:ok, 1_000} = Fleet.start_simulated_fleet(1_000, tick_ms: 0)

    churn =
      Task.async(fn ->
        Enum.each(1..250, fn n ->
          :ok = Fleet.stop("agv-#{n}")
          assert {:ok, _} = Fleet.start_simulated("replacement-#{n}", tick_ms: 0)
        end)
      end)

    samples = Enum.map(1..20, fn _ -> Fleet.snapshot_sample(500, 100) end)
    Task.await(churn, 60_000)

    assert Enum.all?(samples, &(length(&1) <= 500))
    assert Fleet.count() == 1_000
    assert Enum.all?(Fleet.snapshot_sample(500), &is_binary(&1.thing_id))
  end

  @tag :maude
  test "the four-worker Maude pool survives concurrent clean and conflicting reductions" do
    Application.put_env(:goatmire, :verifier, Verifier)

    results =
      1..48
      |> Task.async_stream(
        fn n ->
          rules = if rem(n, 2) == 0, do: Rules.clean_set(), else: Rules.state_conflict_pair()
          Verifier.verify_partitioned(rules, scenario: {:stress, n})
        end,
        max_concurrency: 16,
        ordered: false,
        timeout: 60_000
      )
      |> Enum.to_list()

    assert length(results) == 48

    assert Enum.all?(results, fn
             {:ok, {:ok, %{status: status}, _}} when status in [:clean, :conflicts] -> true
             _ -> false
           end)
  end

  defp assert_eventually(fun, timeout_ms) do
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
        Process.sleep(10)
        eventually(fun, deadline)
    end
  end
end
