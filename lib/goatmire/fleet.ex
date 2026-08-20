defmodule Goatmire.Fleet do
  @moduledoc """
  Supervises this node's devices, simulated and physical alike.

  A device is a process registered under its `thing_id`; what is behind it is
  the device module's business, not the fleet's or the engine's.

      Goatmire.Fleet.start_simulated_fleet(200)
      Goatmire.Fleet.attach_real("agv-01", stale_after_ms: 15_000)

  Simulated devices are a GenServer and a timer each. Beyond one node's
  capacity, run more: each container in `docker/docker-compose.yml` boots its
  own fleet against the shared broker. The simulator profile derives a
  distinct `thing_id` range from each replica hostname.
  """

  alias Goatmire.{Config, Device}

  @registry Goatmire.Fleet.Registry
  @supervisor Goatmire.Fleet.Supervisor

  @doc "Child specs for the registry and dynamic supervisor."
  @spec children() :: [Supervisor.child_spec() | {module(), term()}]
  def children do
    [
      {Registry, keys: :unique, name: @registry},
      {DynamicSupervisor, strategy: :one_for_one, name: @supervisor}
    ]
  end

  @doc "Starts one simulated device."
  @spec start_simulated(String.t(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_simulated(thing_id, opts \\ []) do
    opts = Keyword.put_new(opts, :vda5050, Config.vda5050_enabled?())
    spec = {Device.Simulated, Keyword.put(opts, :thing_id, thing_id)}
    DynamicSupervisor.start_child(@supervisor, spec)
  end

  @doc """
  Starts a simulated AGV fleet.

  `offset` shifts the `thing_id` range so several nodes can populate one
  broker without collisions: node A takes `agv-1..200`, node B `agv-201..400`.
  """
  @spec start_simulated_fleet(non_neg_integer(), keyword()) :: {:ok, non_neg_integer()}
  def start_simulated_fleet(count, opts \\ [])

  def start_simulated_fleet(0, _), do: {:ok, 0}

  def start_simulated_fleet(count, opts) when is_integer(count) and count > 0 do
    offset = Keyword.get(opts, :offset, 0)
    validate_offset!(offset)
    device_opts = Keyword.drop(opts, [:offset])

    started =
      Enum.count((offset + 1)..(offset + count), fn n ->
        match?({:ok, _}, start_simulated("agv-#{n}", device_opts))
      end)

    {:ok, started}
  end

  def start_simulated_fleet(count, _) do
    raise ArgumentError, "fleet count must be a non-negative integer, got: #{inspect(count)}"
  end

  defp validate_offset!(offset) when is_integer(offset) and offset >= 0, do: :ok

  defp validate_offset!(offset) do
    raise ArgumentError, "fleet offset must be a non-negative integer, got: #{inspect(offset)}"
  end

  @doc """
  Declares a physical device, so it appears in the listing and its silence is
  visible. See `Goatmire.Device.Real`.
  """
  @spec attach_real(String.t(), keyword()) :: DynamicSupervisor.on_start_child()
  def attach_real(thing_id, opts \\ []) do
    spec = {Device.Real, Keyword.put(opts, :thing_id, thing_id)}
    DynamicSupervisor.start_child(@supervisor, spec)
  end

  @doc """
  Starts the fixed installations `Goatmire.Rules.clean_set/0` is bound to.
  See `Goatmire.Device.Station`.
  """
  @spec start_stations(keyword()) :: {:ok, non_neg_integer()}
  def start_stations(opts \\ []) do
    started =
      Enum.count(Device.Station.known(), fn thing_id ->
        spec = {Device.Station, Keyword.put(opts, :thing_id, thing_id)}
        match?({:ok, _}, DynamicSupervisor.start_child(@supervisor, spec))
      end)

    {:ok, started}
  end

  @doc "Attaches a 4–20 mA sensor over Modbus TCP. See `Goatmire.Device.ModbusSensor`."
  @spec attach_modbus_sensor(String.t(), keyword()) :: DynamicSupervisor.on_start_child()
  def attach_modbus_sensor(thing_id, opts) do
    spec = {Device.ModbusSensor, Keyword.put(opts, :thing_id, thing_id)}
    DynamicSupervisor.start_child(@supervisor, spec)
  end

  @doc """
  Stops a device and waits until it leaves the registry — `terminate_child/2`
  returns before the registry has processed the exit.
  """
  @spec stop(String.t(), timeout()) :: :ok | {:error, :not_found}
  def stop(thing_id, timeout \\ 5_000) do
    case whereis(thing_id) do
      nil ->
        {:error, :not_found}

      pid ->
        result = DynamicSupervisor.terminate_child(@supervisor, pid)
        await_gone(thing_id, System.monotonic_time(:millisecond) + timeout)
        result
    end
  end

  defp await_gone(thing_id, deadline) do
    cond do
      whereis(thing_id) == nil ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        :ok

      true ->
        Process.sleep(5)
        await_gone(thing_id, deadline)
    end
  end

  @doc """
  Stops every device and waits for the registry to catch up, so a
  stop-then-start (what the storm does) does not mis-size the new fleet.
  """
  @spec stop_all(timeout()) :: :ok
  def stop_all(timeout \\ 5_000) do
    @supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn {_, pid, _, _} -> DynamicSupervisor.terminate_child(@supervisor, pid) end)

    await_empty(System.monotonic_time(:millisecond) + timeout)
  end

  defp await_empty(deadline) do
    cond do
      count() == 0 ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        :ok

      true ->
        Process.sleep(5)
        await_empty(deadline)
    end
  end

  @doc "The pid registered for a `thing_id`, or nil."
  @spec whereis(String.t()) :: pid() | nil
  def whereis(thing_id) do
    case Registry.lookup(@registry, thing_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc "The registry name, for device modules registering themselves."
  @spec registry() :: atom()
  def registry, do: @registry

  @doc "How many devices this node holds."
  @spec count() :: non_neg_integer()
  def count, do: Registry.count(@registry)

  @doc """
  Every device on this node with its current state.

  Sorted by `thing_id` so the dashboard does not reshuffle between renders.
  """
  @spec list() :: [map()]
  def list do
    @registry
    |> Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.map(fn {thing_id, _, meta} -> Map.put(meta, :thing_id, thing_id) end)
    |> Enum.sort_by(& &1.thing_id)
  end

  @doc """
  Live state of each device. Calls every device process — a refresh operation,
  not a hot-path one. `timeout` is per device.
  """
  @spec snapshot(timeout()) :: [map()]
  def snapshot(timeout \\ 1_000) do
    @registry
    |> Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.sort_by(&elem(&1, 0))
    |> snapshot_entries(timeout)
  end

  @doc """
  Live state for at most `limit` devices.

  Non-simulated devices — physical hardware, stations, sensors — are selected
  before the simulated fleet, then each group is sorted by `thing_id`. This
  keeps the dashboard bounded without hiding the bench hardware when a large
  simulated fleet is running.
  """
  @spec snapshot_sample(non_neg_integer(), timeout()) :: [map()]
  def snapshot_sample(limit, timeout \\ 1_000)

  def snapshot_sample(limit, timeout) when is_integer(limit) and limit >= 0 do
    @registry
    |> Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.sort_by(fn {thing_id, _, meta} ->
      {if(Map.get(meta, :kind) == :simulated, do: 1, else: 0), thing_id}
    end)
    |> Enum.take(limit)
    |> Enum.map(fn {thing_id, pid, _} -> {thing_id, pid} end)
    |> snapshot_entries(timeout)
  end

  defp snapshot_entries(entries, timeout) do
    entries
    |> Task.async_stream(
      fn {thing_id, pid} ->
        try do
          GenServer.call(pid, :snapshot, timeout)
        catch
          :exit, _ ->
            %{
              thing_id: thing_id,
              kind: :unknown,
              status: :unreachable,
              battery: nil,
              mode: nil,
              zone: nil,
              destination: nil
            }
        end
      end,
      max_concurrency: 64,
      timeout: timeout * 2,
      on_timeout: :kill_task
    )
    |> Enum.flat_map(fn
      {:ok, snapshot} -> [snapshot]
      {:exit, _} -> []
    end)
  end

  @doc """
  Sends an instruction to every simulated AGV — how a scenario stages a
  shift change. Stations and physical devices never receive one; a real
  battery cannot be told to be flat.
  """
  @spec instruct_all(term()) :: :ok
  def instruct_all(instruction) do
    @registry
    |> Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$2", :"$3"}}]}])
    |> Enum.each(fn
      {pid, %{kind: :simulated}} -> send(pid, {:instruct, instruction})
      {_, _} -> :ok
    end)
  end
end
