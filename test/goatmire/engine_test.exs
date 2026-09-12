defmodule Goatmire.EngineTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Goatmire.{Engine, Rules, StubVerifier, Transport}

  setup do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    StubVerifier.reset()
    :ok = Engine.undeploy()
    :ok = Engine.reset()

    on_exit(fn ->
      Application.delete_env(:goatmire, :verifier)
      StubVerifier.reset()
    end)

    :ok
  end

  describe "deploy/2" do
    test "invalid modes raise in the caller without changing the engine" do
      rules = Rules.clean_set()
      {:ok, _} = Engine.deploy(rules)
      engine = Process.whereis(Engine)
      status = Engine.status()

      assert_raise ArgumentError, ~r/invalid deployment mode/, fn ->
        Engine.deploy([], mode: :typo)
      end

      assert Process.whereis(Engine) == engine
      assert Engine.deployed_rules() == rules
      assert Engine.status().run_id == status.run_id
    end

    test "a clean verdict deploys the whole set" do
      StubVerifier.set(:clean)
      rules = Rules.clean_set()

      assert {:ok, %{deployed: 5, withheld: [], verdict: %{status: :clean}}} =
               Engine.deploy(rules)

      assert Engine.deployed_rules() == rules
    end

    test "a conflict withholds the named rules" do
      [a, b] = Rules.state_conflict_pair()
      StubVerifier.set({:conflicts, [%{type: :state_conflict, rule1: a.id, rule2: b.id}]})

      assert {:ok, %{deployed: 0, withheld: withheld}} =
               Engine.deploy(Rules.state_conflict_pair())

      assert Enum.sort(withheld) == Enum.sort([a.id, b.id])
    end

    test "observe mode deploys a conflicting set and still reports the verdict" do
      [a, b] = Rules.state_conflict_pair()
      StubVerifier.set({:conflicts, [%{type: :state_conflict, rule1: a.id, rule2: b.id}]})

      assert {:ok, %{deployed: 2, withheld: [], verdict: %{status: :conflicts}}} =
               Engine.deploy(Rules.state_conflict_pair(), mode: :observe)
    end

    test "unverified deploys nothing, even in observe mode" do
      StubVerifier.set(:unverified)

      assert {:ok, %{deployed: 0, verdict: %{status: :unverified}}} =
               Engine.deploy(Rules.clean_set(), mode: :observe)

      assert Engine.status().deployed_count == 0
    end

    test "an invalid rule in an unverified set does not crash the engine" do
      StubVerifier.set(:unverified)

      assert {:ok, %{deployed: 0, withheld: ["invalid-rule-1"]}} =
               Engine.deploy([%{}])

      assert Process.alive?(Process.whereis(Engine))
    end
  end

  defmodule SlowVerifier do
    @moduledoc false
    @behaviour Goatmire.Gate
    @impl true
    def verify_partitioned(rules, opts) do
      send(Keyword.fetch!(opts, :observer), {:checking, self()})
      Process.sleep(500)
      StubVerifier.verify_partitioned(rules, opts)
    end

    @impl true
    defdelegate verify(rules, opts), to: StubVerifier
    @impl true
    defdelegate split_on_verdict(rules, verdict), to: StubVerifier
    @impl true
    defdelegate health(), to: StubVerifier
  end

  test "slow verification leaves ingestion responsive and cannot activate after its deadline" do
    Application.put_env(:goatmire, :verifier, SlowVerifier)
    parent = self()
    task = Task.async(fn -> Engine.deploy(Rules.clean_set(), timeout: 150, observer: parent) end)
    assert_receive {:checking, worker}
    monitor = Process.monitor(worker)

    send(
      Engine,
      {:goatmire_publish, Transport.telemetry_topic("responsive"),
       %{thing_id: "responsive", property: "battery", value: 12}}
    )

    assert Engine.properties("responsive")["battery"] == 12
    assert Engine.status().deployed_count == 0
    assert {:ok, %{verdict: %{status: :unverified}}} = Task.await(task)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}
    assert Engine.deployed_rules() == []
  end

  test "concurrent admissions retain every accepted addition" do
    rules = Rules.clean_set()
    results = Task.async_stream(rules, &Engine.admit([&1]), max_concurrency: 5) |> Enum.to_list()
    assert Enum.all?(results, &match?({:ok, {:ok, %{withheld: []}}}, &1))
    assert MapSet.new(Engine.deployed_rules()) == MapSet.new(rules)
  end

  test "a rejected addition preserves the active rules" do
    [first, second] = Rules.state_conflict_pair()
    {:ok, _} = Engine.deploy([first])
    StubVerifier.set(:unverified)
    assert {:ok, %{withheld: [_]}} = Engine.admit([second])
    assert Engine.deployed_rules() == [first]
  end

  defmodule FailingTransport do
    @moduledoc false
    @spec publish(term(), term()) :: {:error, :disconnected}
    def publish(_, _), do: {:error, :disconnected}
  end

  test "failed delivery does not change the world or count an alert" do
    [rule, _] = Rules.state_conflict_pair()
    {:ok, _} = Engine.deploy([rule])
    transport = Transport.impl()
    Application.put_env(:goatmire, :transport, FailingTransport)
    on_exit(fn -> Application.put_env(:goatmire, :transport, transport) end)

    send(
      Engine,
      {:goatmire_publish, Transport.telemetry_topic("agv-42"),
       %{thing_id: "agv-42", property: "battery", value: 12}}
    )

    status = Engine.status()
    assert status.counters.alerts == 0
    assert status.delivery_failures == 1
    refute Map.has_key?(Engine.properties("agv-42"), "destination")
  end

  describe "ingest" do
    test "publishes a type-changing write and an explicit null to an unseen property" do
      rule = %{
        id: "typed-write",
        thing_id: "typed-device",
        trigger: {:prop_eq, "ready", true},
        actions: [
          {:set_prop, "typed-device", "reading", 1.0},
          {:set_prop, "typed-device", "nullable", nil}
        ]
      }

      {:ok, _} = Engine.deploy([rule])
      :ok = Transport.subscribe_commands("typed-device")
      topic = Transport.telemetry_topic("typed-device")

      send(
        Engine,
        {:goatmire_publish, topic, %{thing_id: "typed-device", property: "reading", value: 1}}
      )

      send(
        Engine,
        {:goatmire_publish, topic, %{thing_id: "typed-device", property: "ready", value: true}}
      )

      assert Engine.status().counters.alerts == 2

      assert_receive {:goatmire_publish, "goatmire/things/typed-device/command",
                      %{"property" => "reading", "value" => value}}

      assert value === 1.0

      assert_receive {:goatmire_publish, "goatmire/things/typed-device/command",
                      %{"property" => "nullable", "value" => nil}}

      assert Map.fetch(Engine.properties("typed-device"), "nullable") === {:ok, nil}
    end

    test "a reading that satisfies no trigger produces no alert" do
      StubVerifier.set(:clean)
      {:ok, _} = Engine.deploy(Rules.state_conflict_pair())

      Transport.publish_telemetry("agv-42", "battery", 80)
      settle()

      assert %{events: events, alerts: 0} = Engine.status().counters
      assert events >= 1
    end

    test "a satisfied trigger actuates and counts one alert" do
      StubVerifier.set(:clean)
      [route_rule, _] = Rules.state_conflict_pair()
      {:ok, _} = Engine.deploy([route_rule])

      Transport.publish_telemetry("agv-42", "battery", 12)
      settle()

      assert Engine.status().counters.alerts == 1

      assert [%{thing_id: "agv-42", property: "destination", total: 1}] =
               Engine.status().recent_alerts

      assert Engine.properties("agv-42")["destination"] == "dock-7"
    end

    test "re-asserting a value the Thing already holds is not a new alert" do
      StubVerifier.set(:clean)
      [route_rule, _] = Rules.state_conflict_pair()
      {:ok, _} = Engine.deploy([route_rule])

      Transport.publish_telemetry("agv-42", "battery", 12)
      settle()
      Transport.publish_telemetry("agv-42", "battery", 11)
      settle()

      assert Engine.status().counters.alerts == 1
    end

    test "a conflicting pair deployed in observe mode oscillates — two alerts per reading" do
      [a, b] = Rules.state_conflict_pair()
      StubVerifier.set({:conflicts, [%{type: :state_conflict, rule1: a.id, rule2: b.id}]})
      {:ok, %{deployed: 2}} = Engine.deploy([a, b], mode: :observe)

      Transport.publish_telemetry("agv-42", "hour", 10)
      settle()
      Transport.publish_telemetry("agv-42", "battery", 12)
      settle()

      assert Engine.status().counters.alerts >= 2
    end

    test "the same pair behind the gate never actuates at all" do
      [a, b] = Rules.state_conflict_pair()
      StubVerifier.set({:conflicts, [%{type: :state_conflict, rule1: a.id, rule2: b.id}]})
      {:ok, %{deployed: 0}} = Engine.deploy([a, b], mode: :enforce)

      Transport.publish_telemetry("agv-42", "hour", 10)
      settle()
      Transport.publish_telemetry("agv-42", "battery", 12)
      settle()

      assert Engine.status().counters.alerts == 0
    end
  end

  describe "throttling" do
    test "commands to one Thing are bounded, and the drops are counted" do
      [a, b] = Rules.state_conflict_pair()
      StubVerifier.set(:clean)
      {:ok, %{deployed: 2}} = Engine.deploy([a, b], mode: :observe)

      Transport.publish_telemetry("agv-42", "hour", 10)
      settle()

      Enum.each(1..40, fn n ->
        Transport.publish_telemetry("agv-42", "battery", rem(n, 19) + 1)
      end)

      settle(300)

      status = Engine.status()
      counters = status.counters
      assert counters.throttled > 0, "expected the per-Thing bound to drop commands"
      assert counters.alerts <= 20, "alerts should be capped by the window bound"
      assert length(status.recent_alerts) == 12, "the dashboard feed must stay bounded"
    end
  end

  defp settle(ms \\ 80), do: Process.sleep(ms)
end
