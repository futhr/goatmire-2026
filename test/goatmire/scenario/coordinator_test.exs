defmodule Goatmire.Scenario.CoordinatorTest do
  use ExUnit.Case, async: false
  alias Goatmire.Scenario.Coordinator

  test "the scenario worker stops when its initiating caller dies" do
    parent = self()

    caller =
      spawn(fn ->
        Coordinator.exclusive(fn ->
          send(parent, {:worker, self()})
          Process.sleep(:infinity)
        end)
      end)

    assert_receive {:worker, worker}
    ref = Process.monitor(worker)
    Process.exit(caller, :kill)
    assert_receive {:DOWN, ^ref, :process, ^worker, _}, 1_000
    refute Coordinator.status().running
  end

  test "a second client cannot mutate the fleet during a scenario" do
    parent = self()

    task =
      Task.async(fn ->
        Coordinator.exclusive(fn ->
          send(parent, {:entered, self()})

          receive do
            :finish -> :done
          end
        end)
      end)

    assert_receive {:entered, worker}
    assert Coordinator.status().running
    assert {:error, :busy} = Coordinator.exclusive(fn -> flunk("second operation ran") end)
    send(worker, :finish)
    assert Task.await(task) == :done
    refute Coordinator.status().running
  end
end
