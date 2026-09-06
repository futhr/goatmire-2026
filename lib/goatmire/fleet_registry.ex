defmodule Goatmire.FleetRegistry do
  @moduledoc "Waits for the old registry partition to exit before replacing its supervisor."

  @doc "Starts the single-partition fleet registry without racing old name cleanup."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    case Process.whereis(Goatmire.Fleet.Registry.PIDPartition0) do
      nil ->
        Registry.start_link(opts)

      pid ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, _} -> Registry.start_link(opts)
        after
          1_000 ->
            Process.demonitor(ref, [:flush])
            {:error, :registry_cleanup_timeout}
        end
    end
  end
end
