defmodule Goatmire.LocalClusterTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Goatmire.LocalCluster

  setup do
    LocalCluster.stop()
    on_exit(&LocalCluster.stop/0)
    :ok
  end

  test "nodes/0 reports no peers before the cluster is started" do
    assert LocalCluster.nodes() == []
  end

  test "rejects an unbounded peer count before creating node-name atoms" do
    assert_raise ArgumentError, ~r/node_count 1\.\.16/, fn ->
      LocalCluster.start(node_count: 17)
    end

    assert_raise ArgumentError, ~r/fleet_per_node > 0/, fn ->
      LocalCluster.start(fleet_per_node: 0)
    end
  end

  # `start/1` boots `:peer` nodes and needs epmd plus a distributed BEAM. Peer
  # bring-up is slow and flaky in ephemeral runners, so it is a rehearsal step
  # rather than a CI test — see docs/runbooks/rehearsal.md. The container swarm in
  # docker/docker-compose.yml covers the same ground more honestly, with a real
  # broker between the nodes.
  @tag :manual
  test "starts peers and gives each one a fleet partition" do
    assert {:ok, nodes} = LocalCluster.start(node_count: 2, fleet_per_node: 5, tick_ms: 0)
    assert length(nodes) == 2
    assert LocalCluster.ensure_started!() == :ok
    assert Enum.map(nodes, &:erpc.call(&1, Goatmire.Fleet, :count, [])) == [5, 5]

    ids =
      Enum.flat_map(nodes, fn node ->
        node
        |> :erpc.call(Goatmire.Fleet, :list, [])
        |> Enum.map(& &1.thing_id)
      end)

    assert length(Enum.uniq(ids)) == 10

    assert :ok = LocalCluster.stop()
    assert LocalCluster.nodes() == []
  end
end
