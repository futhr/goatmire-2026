defmodule Goatmire.ConsoleTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Goatmire.{Console, Engine, Fleet, Transport}

  setup do
    Console.reset()
    on_exit(&Console.reset/0)
    :ok
  end

  test "help is a copy-pasteable operator map" do
    output = capture_io(&Console.help/0)

    assert output =~ "GM.status()"
    assert output =~ "GM.observe"
    assert output =~ "GM.verify"
    assert output =~ "release shell"
  end

  test "status and snapshot expose the same bounded runtime used by the dashboard" do
    status = Console.status()
    snapshot = Console.snapshot()

    assert is_map(status.engine)
    assert is_integer(status.fleet_devices)
    assert match?({:ok, _}, status.maude) or match?({:error, _}, status.maude)
    assert is_map(status.diagnostics)
    assert is_map(snapshot.current)
  end

  test "fleet and Thing helpers operate through public runtime boundaries" do
    assert {:ok, 2} = Console.start_fleet(2, tick_ms: 0)
    assert Fleet.count() == 2

    :ok = Transport.publish_telemetry("console-agv", "battery", 41)
    assert_eventually(fn -> Console.thing("console-agv")["battery"] == 41 end)

    assert :ok = Console.reset()
    assert Fleet.count() == 0
    assert Engine.status().deployed_count == 0
    assert Engine.status().counters == %{events: 0, alerts: 0, throttled: 0}
  end

  defp assert_eventually(fun, attempts \\ 30)
  defp assert_eventually(fun, 0), do: assert(fun.())

  defp assert_eventually(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end
end
