defmodule Goatmire.Transport.LocalTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Goatmire.Transport
  alias Goatmire.Transport.Local

  describe "topic_match?/2" do
    test "matches an exact topic" do
      assert Local.topic_match?(
               "goatmire/things/agv-1/telemetry",
               "goatmire/things/agv-1/telemetry"
             )
    end

    test "+ matches exactly one level" do
      assert Local.topic_match?("goatmire/things/agv-1/telemetry", "goatmire/things/+/telemetry")

      refute Local.topic_match?(
               "goatmire/things/agv-1/x/telemetry",
               "goatmire/things/+/telemetry"
             )
    end

    test "# matches the remainder" do
      assert Local.topic_match?("goatmire/things/agv-1/telemetry", "goatmire/#")
      assert Local.topic_match?("goatmire/alerts", "goatmire/#")
    end

    test "a longer topic does not match a shorter filter" do
      refute Local.topic_match?("goatmire/things/agv-1/telemetry", "goatmire/things")
    end

    test "a shorter topic does not match a longer filter" do
      refute Local.topic_match?("goatmire/things", "goatmire/things/agv-1/telemetry")
    end

    test "a differing level does not match" do
      refute Local.topic_match?("goatmire/things/agv-1/command", "goatmire/things/+/telemetry")
    end
  end

  describe "publish and subscribe" do
    test "a subscriber receives only the topics it asked for" do
      :ok = Transport.subscribe_commands("agv-7")

      :ok = Transport.publish_command("agv-7", "destination", "dock-3")
      :ok = Transport.publish_command("agv-8", "destination", "dock-4")
      :ok = Transport.publish_telemetry("agv-7", "battery", 11)

      accepted = drain_accepted()

      assert [%{"thing_id" => "agv-7", "property" => "destination", "value" => "dock-3"}] =
               accepted
    end

    test "wildcard telemetry subscription receives every device" do
      :ok = Transport.subscribe_all_telemetry()

      :ok = Transport.publish_telemetry("agv-1", "battery", 50)
      :ok = Transport.publish_telemetry("agv-2", "battery", 40)

      assert length(drain_accepted()) == 2
    end
  end

  defp drain_accepted(acc \\ []) do
    receive do
      {:goatmire_publish, _, _} = message ->
        case Local.accept(message) do
          {:ok, _, payload} -> drain_accepted([payload | acc])
          :ignore -> drain_accepted(acc)
        end
    after
      50 -> Enum.reverse(acc)
    end
  end
end
