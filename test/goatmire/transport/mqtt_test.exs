defmodule Goatmire.Transport.MQTTTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Goatmire.Transport.{Local, MQTT, MQTT.Handler}

  setup do
    previous = Application.get_env(:goatmire, :mqtt)

    on_exit(fn ->
      if previous do
        Application.put_env(:goatmire, :mqtt, previous)
      else
        Application.delete_env(:goatmire, :mqtt)
      end
    end)

    :ok
  end

  test "merges explicit MQTT settings with safe defaults" do
    Application.put_env(:goatmire, :mqtt, host: "broker", client_id: "test-client")

    config = MQTT.config()
    assert config[:host] == "broker"
    assert config[:port] == 1883
    assert config[:client_id] == "test-client"
    assert config[:username] == nil
  end

  test "child spec carries the configured broker session" do
    Application.put_env(:goatmire, :mqtt,
      host: "broker",
      port: 1884,
      client_id: "spec-client",
      username: "demo",
      password: "secret"
    )

    assert %{id: MQTT, type: :supervisor, restart: :permanent, start: start} = MQTT.child_spec([])
    assert {Tortoise311.Connection, :start_link, [options]} = start
    assert options[:client_id] == "spec-client"
    assert options[:server] == {Tortoise311.Transport.Tcp, host: "broker", port: 1884}
    assert options[:handler] == {Handler, []}
  end

  test "handler decodes broker JSON onto the local fan-out" do
    :ok = Local.subscribe("goatmire/things/+/telemetry")
    {:ok, state} = Handler.init([])

    payload = Jason.encode!(%{"thing_id" => "agv-9", "property" => "battery", "value" => 18})

    assert {:ok, ^state} =
             Handler.handle_message(~w(goatmire things agv-9 telemetry), payload, state)

    assert_receive {:goatmire_publish, "goatmire/things/agv-9/telemetry", decoded}, 500
    assert decoded["value"] == 18
  end

  test "handler drops malformed JSON without crashing" do
    {:ok, state} = Handler.init([])

    log =
      capture_log(fn ->
        assert {:ok, ^state} =
                 Handler.handle_message(~w(goatmire things bad telemetry), "{", state)
      end)

    assert log =~ "undecodable payload"
    assert {:ok, ^state} = Handler.connection(:up, state)
    assert {:ok, ^state} = Handler.subscription(:up, "goatmire/#", state)
    assert :ok = Handler.terminate(:normal, state)
  end
end
