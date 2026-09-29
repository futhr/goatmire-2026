defmodule Goatmire.Talk.StageCleanupTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.{Engine, Fleet}
  alias Goatmire.Talk.StageCleanup

  setup do
    Fleet.stop_all()
    on_exit(&Fleet.stop_all/0)
    {:ok, cleanup} = StageCleanup.start_link(name: nil, subscribe: false)
    %{cleanup: cleanup}
  end

  test "only a move out of the storm slides counts as leaving" do
    assert StageCleanup.leaving?(21, 22)
    assert StageCleanup.leaving?(20, 19)
    assert StageCleanup.leaving?(20, 31)
    refute StageCleanup.leaving?(20, 21)
    refute StageCleanup.leaving?(19, 20)
    refute StageCleanup.leaving?(nil, 23)
  end

  test "leaving forward stops the fleet and empties the floor", %{cleanup: cleanup} do
    {:ok, _} = Fleet.start_simulated_fleet(3, tick_ms: 50)
    assert_eventually(fn -> Engine.status().observed_things != [] end)

    send(cleanup, {:talk_clock, %{slide: 21}})
    send(cleanup, {:talk_clock, %{slide: 22}})

    assert_eventually(fn -> Fleet.count() == 0 and Engine.status().observed_things == [] end)
  end

  test "moving back also clears, and staying inside does not", %{cleanup: cleanup} do
    {:ok, _} = Fleet.start_simulated_fleet(2, tick_ms: 50)

    send(cleanup, {:talk_clock, %{slide: 20}})
    send(cleanup, {:talk_clock, %{slide: 21}})
    :sys.get_state(cleanup)
    assert Fleet.count() == 2

    send(cleanup, {:talk_clock, %{slide: 19}})
    assert_eventually(fn -> Fleet.count() == 0 end)
  end

  defp assert_eventually(fun, attempts \\ 80)
  defp assert_eventually(fun, 0), do: assert(fun.())

  defp assert_eventually(fun, attempts) do
    unless fun.() do
      Process.sleep(25)
      assert_eventually(fun, attempts - 1)
    end
  end
end
