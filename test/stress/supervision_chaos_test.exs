defmodule Goatmire.SupervisionChaosTest do
  @moduledoc """
  The no-fallback bet: a demo-domain meltdown must never take the endpoint or
  the talk clock with it. Each test kills real processes and asserts the blast
  radius stayed inside `Goatmire.Demo.Supervisor`.
  """

  use ExUnit.Case, async: false

  alias Goatmire.Diagnostics.Sampler
  alias Goatmire.Talk.Clock

  @moduletag :stress
  @moduletag timeout: 120_000

  setup do
    Clock.reset()
    on_exit(fn -> Clock.reset() end)
    :ok
  end

  test "a crash-looping sampler melts the demo branch; endpoint and clock hold position" do
    Clock.goto(7)
    endpoint = Process.whereis(GoatmireWeb.Endpoint)
    clock = Process.whereis(Clock)
    demo = Process.whereis(Goatmire.Demo.Supervisor)

    # More kills than the demo supervisor's restart budget (10 in 10s): the
    # branch itself must die and be restarted by the root. This is the
    # realistic meltdown — supervisors die by intensity exhaustion, which
    # terminates children cleanly before the root restarts the branch.
    kill_until_meltdown(demo, 30)

    assert_eventually(fn ->
      new_demo = Process.whereis(Goatmire.Demo.Supervisor)
      is_pid(new_demo) and new_demo != demo and is_pid(Process.whereis(Sampler))
    end)

    assert Process.whereis(GoatmireWeb.Endpoint) == endpoint
    assert Process.whereis(Clock) == clock
    assert %{slide: 7, started?: true} = Clock.snapshot()
  end

  test "killing the verifier pool restarts the engine with it, and both recover" do
    endpoint = Process.whereis(GoatmireWeb.Endpoint)

    {pool_id, pool_pid, _, _} =
      Goatmire.Engine.Supervisor
      |> Supervisor.which_children()
      |> Enum.find(fn {id, _, _, _} ->
        id not in [Goatmire.Engine, Goatmire.Protocol.VDA5050.Bridge]
      end)

    assert is_pid(pool_pid), "expected the pool child #{inspect(pool_id)} to be running"

    ref = Process.monitor(pool_pid)
    Process.exit(pool_pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pool_pid, _}, 5_000

    assert_eventually(fn ->
      Goatmire.Engine.Supervisor
      |> Supervisor.which_children()
      |> Enum.all?(fn {_, pid, _, _} -> is_pid(pid) end)
    end)

    assert_eventually(fn ->
      try do
        match?(%{}, Goatmire.Engine.status())
      catch
        :exit, _ -> false
      end
    end)

    assert Process.whereis(GoatmireWeb.Endpoint) == endpoint
  end

  test "the talk clock restores slide position and keeps ticking after its own crash" do
    Clock.goto(9)
    clock = Process.whereis(Clock)

    ref = Process.monitor(clock)
    Process.exit(clock, :kill)
    assert_receive {:DOWN, ^ref, :process, ^clock, _}, 5_000

    assert_eventually(fn -> is_pid(Process.whereis(Clock)) end)
    assert %{slide: 9, started?: true} = Clock.snapshot()

    Phoenix.PubSub.subscribe(Goatmire.PubSub, Clock.topic())
    assert_receive {:talk_clock, %{slide: 9}}, 3_000
  end

  # Kills the sampler until the demo branch itself falls over (pid changes or
  # vanishes mid-restart). Only landed kills consume attempts, so the branch
  # budget is always exceeded inside its 10-second window.
  defp kill_until_meltdown(_demo, 0), do: flunk("demo branch never exhausted its restart budget")

  defp kill_until_meltdown(demo, attempts_left) do
    cond do
      Process.whereis(Goatmire.Demo.Supervisor) != demo ->
        :melted

      pid = Process.whereis(Sampler) ->
        ref = Process.monitor(pid)
        Process.exit(pid, :kill)
        assert_receive {:DOWN, ^ref, :process, ^pid, _}, 5_000
        kill_until_meltdown(demo, attempts_left - 1)

      true ->
        Process.sleep(10)
        kill_until_meltdown(demo, attempts_left)
    end
  end

  defp assert_eventually(fun, timeout_ms \\ 10_000) do
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
        Process.sleep(25)
        eventually(fun, deadline)
    end
  end
end
