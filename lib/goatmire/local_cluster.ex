defmodule Goatmire.LocalCluster do
  @moduledoc """
  Boots extra BEAM nodes on this machine, each with a slice of the fleet.

  The laptop-scale version of the Docker swarm. These are peer nodes sharing
  one kernel and one network stack — they show the fleet partitions, not that
  it survives a datacentre. For that, use `docker/docker-compose.yml` with a
  broker between the nodes.
  """

  alias Goatmire.Config

  @peer_names [
    :goatmire1,
    :goatmire2,
    :goatmire3,
    :goatmire4,
    :goatmire5,
    :goatmire6,
    :goatmire7,
    :goatmire8,
    :goatmire9,
    :goatmire10,
    :goatmire11,
    :goatmire12,
    :goatmire13,
    :goatmire14,
    :goatmire15,
    :goatmire16
  ]
  @max_peers length(@peer_names)
  @peers_key {__MODULE__, :peers}
  @child_env [
    {"ANTHROPIC_API_KEY", nil},
    {"GITHUB_TOKEN", nil},
    {"GH_TOKEN", nil},
    {"OPENAI_API_KEY", nil},
    {"SSH_AUTH_SOCK", nil}
  ]

  @doc "Boots the cluster if it is not already up."
  @spec ensure_started!() :: :ok
  def ensure_started! do
    case nodes() do
      [] ->
        {:ok, _} = start()
        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Boots `node_count` peers and starts a fleet partition on each.

  ## Options

    * `:node_count` — peers to boot (default 4)
    * `:fleet_per_node` — simulated devices per peer (default 50)
    * `:tick_ms` — device physics tick on the peers
  """
  @spec start(keyword()) :: {:ok, [node()]}
  def start(opts \\ []) do
    node_count = Keyword.get(opts, :node_count, 4)
    fleet_per_node = Keyword.get(opts, :fleet_per_node, 50)
    tick_ms = Keyword.get(opts, :tick_ms, Config.device_tick_ms())

    validate_options!(node_count, fleet_per_node, tick_ms)
    :ok = ensure_epmd_running()
    :ok = ensure_distributed()

    case nodes() do
      [] -> start_peers(node_count, fleet_per_node, tick_ms)
      existing -> {:ok, existing}
    end
  end

  @doc "Stops every peer this module started."
  @spec stop() :: :ok
  def stop do
    tracked_peers()
    |> Enum.each(fn {pid, _} -> stop_peer(pid) end)

    :persistent_term.erase(@peers_key)
    :ok
  end

  @doc "Peers currently connected."
  @spec nodes() :: [node()]
  def nodes do
    connected = MapSet.new(Node.list())

    tracked_peers()
    |> Enum.filter(fn {pid, node} -> Process.alive?(pid) and MapSet.member?(connected, node) end)
    |> Enum.map(&elem(&1, 1))
  end

  defp validate_options!(node_count, fleet_per_node, tick_ms)
       when is_integer(node_count) and node_count >= 1 and node_count <= @max_peers and
              is_integer(fleet_per_node) and
              fleet_per_node > 0 and is_integer(tick_ms) and tick_ms >= 0,
       do: :ok

  defp validate_options!(node_count, fleet_per_node, tick_ms) do
    raise ArgumentError,
          "expected node_count 1..#{@max_peers}, fleet_per_node > 0, and tick_ms >= 0; " <>
            "got #{inspect(node_count)}, #{inspect(fleet_per_node)}, #{inspect(tick_ms)}"
  end

  defp start_peers(node_count, fleet_per_node, tick_ms) do
    result =
      Enum.reduce_while(1..node_count, {:ok, []}, fn index, {:ok, peers} ->
        case start_one_peer(index, fleet_per_node, tick_ms) do
          {:ok, peer} ->
            {:cont, {:ok, [peer | peers]}}

          {:error, reason} ->
            {:halt, {:error, reason, peers}}
        end
      end)

    case result do
      {:ok, peers} ->
        peers = Enum.reverse(peers)
        :persistent_term.put(@peers_key, peers)
        {:ok, Enum.map(peers, &elem(&1, 1))}

      {:error, reason, peers} ->
        Enum.each(peers, fn {pid, _} -> stop_peer(pid) end)
        raise "could not start local cluster: #{inspect(reason)}"
    end
  end

  defp start_one_peer(index, fleet_per_node, tick_ms) do
    case start_peer(index) do
      {:ok, pid, node} ->
        case bootstrap_peer(node, fleet_per_node, tick_ms, index) do
          :ok ->
            {:ok, {pid, node}}

          {:error, reason} ->
            stop_peer(pid)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ensure_epmd_running do
    System.cmd("epmd", ["-daemon"], stderr_to_stdout: true, env: @child_env)
    :ok
  rescue
    _ -> :ok
  end

  defp ensure_distributed do
    case node() do
      :nonode@nohost ->
        {:ok, _} = Node.start(:"goatmire@127.0.0.1", name_domain: :longnames)
        Node.set_cookie(:goatmire_demo)
        :ok

      _ ->
        :ok
    end
  end

  defp start_peer(n) do
    :peer.start(%{
      name: Enum.fetch!(@peer_names, n - 1),
      host: ~c"127.0.0.1",
      longnames: true,
      args: [~c"-setcookie", ~c"goatmire_demo"]
    })
  end

  defp bootstrap_peer(node, fleet_per_node, tick_ms, index) do
    :erpc.call(node, :code, :add_paths, [:code.get_path()])

    Enum.each(
      [
        role: :simulator,
        transport: Goatmire.Transport.Local,
        metrics_enabled: false,
        autostart_fleet: false
      ],
      fn {key, value} -> :erpc.call(node, Application, :put_env, [:goatmire, key, value]) end
    )

    with {:ok, _} <- :erpc.call(node, Application, :ensure_all_started, [:goatmire]),
         {:ok, ^fleet_per_node} <-
           start_fleet_on(node, fleet_per_node, tick_ms, (index - 1) * fleet_per_node) do
      :ok
    else
      other -> {:error, {:peer_boot_failed, node, other}}
    end
  rescue
    error -> {:error, {:peer_boot_failed, node, Exception.message(error)}}
  catch
    :exit, reason -> {:error, {:peer_boot_failed, node, reason}}
  end

  defp start_fleet_on(node, count, tick_ms, offset) do
    :erpc.call(node, Goatmire.Fleet, :start_simulated_fleet, [
      count,
      [offset: offset, tick_ms: tick_ms]
    ])
  end

  defp tracked_peers, do: :persistent_term.get(@peers_key, [])

  defp stop_peer(pid) do
    :peer.stop(pid)
  catch
    :exit, _ -> :ok
  end
end
