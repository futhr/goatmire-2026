defmodule Goatmire.Talk.ClockTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.Talk.Clock

  setup do
    Clock.reset()
    on_exit(fn -> Clock.reset() end)
    :ok
  end

  test "loads budgets that fit the slot with no warnings" do
    snap = Clock.snapshot()

    assert snap.warnings == []
    assert snap.slide_count == 25
    assert snap.budget_total_s <= snap.slot_s
  end

  test "navigation starts the talk and applies the slide's panel and tab" do
    assert %{started?: false, slide: 1} = Clock.snapshot()

    snap = Clock.next()
    assert snap.started?
    assert snap.slide == 2

    snap = Clock.goto(16)
    assert snap.panel == :live_full
    assert snap.tab == :rules

    snap = Clock.goto(13)
    assert snap.panel == :split
    assert snap.tab == :code
  end

  test "every tab a slide can configure is accepted by the clock" do
    for {_slide, tab} <- [{16, :rules}, {17, :warehouse}, {18, :diagnostics}, {22, :notebook}] do
      assert %{tab: ^tab} = Clock.set_tab(tab)
    end
  end

  test "slide 22 opens the notebook pane" do
    assert %{tab: :notebook, panel: :live_full} = Clock.goto(22)
  end

  test "manual panel and tab overrides hold only until the next slide change" do
    Clock.goto(6)

    assert %{panel: :live_full} = Clock.set_panel(:live_full)
    assert %{tab: :metrics} = Clock.set_tab(:metrics)

    snap = Clock.next()
    assert snap.panel == :split
    assert snap.tab == :code
  end

  test "reset returns to slide 1 unstarted" do
    Clock.goto(12)

    assert %{slide: 1, started?: false, talk_elapsed_s: 0} = Clock.reset()
  end

  test "position survives a clock restart" do
    Clock.goto(9)
    pid = Process.whereis(Clock)
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 5_000

    assert_eventually(fn ->
      case Process.whereis(Clock) do
        nil -> false
        new_pid -> new_pid != pid
      end
    end)

    assert %{slide: 9, started?: true} = Clock.snapshot()
  end

  test "broadcasts a snapshot on every mutation" do
    Phoenix.PubSub.subscribe(Goatmire.PubSub, Clock.topic())
    Clock.goto(3)

    assert_receive {:talk_clock, %{slide: 3}}, 1_000
  end

  test "zoom steps by 0.1 and clamps to 0.7–1.5" do
    Enum.each(1..10, fn _ -> Clock.zoom(:in) end)
    assert %{zoom: 1.5} = Clock.snapshot()

    Enum.each(1..12, fn _ -> Clock.zoom(:out) end)
    assert %{zoom: 0.7} = Clock.snapshot()

    assert %{zoom: 1.0} = Clock.reset()
  end

  test "reset_clock restarts the timer but keeps slide, layout, and zoom" do
    Clock.goto(16)
    Clock.zoom(:in)
    Process.sleep(1_100)

    snap = Clock.reset_clock()

    assert snap.slide == 16
    assert snap.panel == :live_full
    assert snap.zoom == 1.1
    assert snap.started?
    assert snap.talk_elapsed_s <= 1
  end

  test "the timer does not start on slide 1" do
    Clock.goto(1)
    assert %{started?: false} = Clock.snapshot()

    Clock.next()
    assert %{started?: true, slide: 2} = Clock.snapshot()
  end

  test "before the talk starts, a restart applies the slide's configured layout" do
    Clock.set_panel(:split)
    assert %{panel: :split, started?: false} = Clock.snapshot()

    kill_and_await_restart()

    assert %{slide: 1, panel: :deck_full} = Clock.snapshot()
  end

  test "mid-talk, a restart keeps the presenter's manual layout" do
    Clock.goto(4)
    Clock.set_panel(:live_full)

    kill_and_await_restart()

    assert %{slide: 4, panel: :live_full, started?: true} = Clock.snapshot()
  end

  defp kill_and_await_restart do
    pid = Process.whereis(Clock)
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 5_000

    assert_eventually(fn ->
      case Process.whereis(Clock) do
        nil -> false
        new_pid -> new_pid != pid
      end
    end)
  end

  defp assert_eventually(fun, timeout_ms \\ 5_000) do
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
