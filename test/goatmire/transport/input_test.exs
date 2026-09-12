defmodule Goatmire.Transport.InputTest do
  use ExUnit.Case, async: true
  alias Goatmire.Transport

  test "normalizes nested objects without losing JSON types" do
    value = %{position: %{x: 1, y: 1.0}, flags: [true, false, nil]}
    assert {:ok, event} = Transport.decode_event(%{thing_id: "a", property: "p", value: value})
    assert event.value === %{"position" => %{"x" => 1, "y" => 1.0}, "flags" => [true, false, nil]}
  end

  test "rejects key collisions and malformed or excessive collection structure" do
    base = %{thing_id: "a", property: "p", value: 1}
    assert :error = Transport.decode_event(Map.put(base, "thing_id", "b"))

    for value <- [
          %{:x => 1, "x" => 2},
          %{nested: %{:x => 1, "x" => 2}},
          [1 | 2],
          Enum.to_list(1..33),
          [[[[[1]]]]]
        ] do
      assert :error = Transport.decode_event(%{base | value: value})
    end
  end

  test "rejects malformed identifiers and oversized or structured values" do
    for {thing, property, value} <- [
          {[], "battery", 1},
          {"agv-1", %{}, 1},
          {"a/+/b", "p", 1},
          {"agv-1", "p", %{bad: self()}},
          {"agv-1", "p", String.duplicate("x", 1025)}
        ] do
      assert :error = Transport.decode_event(%{thing_id: thing, property: property, value: value})
    end
  end

  test "the topic and payload must identify the same device" do
    event = %{thing_id: "agv-1", property: "battery", value: 10}
    assert {:ok, ^event} = Transport.decode_event(event, Transport.telemetry_topic("agv-1"))
    assert :error = Transport.decode_event(event, Transport.telemetry_topic("agv-2"))
  end

  test "MQTT wildcards preserve system topics and require terminal hash" do
    refute Transport.Local.topic_match?("$SYS/status", "#")
    assert Transport.Local.topic_match?("$SYS/status", "$SYS/#")
    refute Transport.Local.topic_match?("a/b", "#/b")
  end
end
