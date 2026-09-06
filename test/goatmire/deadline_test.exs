defmodule Goatmire.DeadlineTest do
  use ExUnit.Case, async: true

  alias Goatmire.Deadline

  test "a deadline stops the worker" do
    parent = self()

    assert {:error, :timeout} =
             Deadline.run(
               fn ->
                 send(parent, {:worker, self()})
                 Process.sleep(:infinity)
               end,
               30
             )

    assert_receive {:worker, worker}
    refute Process.alive?(worker)
  end

  test "a caller exit stops its worker" do
    parent = self()

    owner =
      spawn(fn ->
        Deadline.run(
          fn ->
            send(parent, {:worker, self()})
            Process.sleep(:infinity)
          end,
          30_000
        )
      end)

    assert_receive {:worker, worker}
    monitor = Process.monitor(worker)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
  end
end
