defmodule Goatmire.Deadline do
  @moduledoc "Runs work within a deadline and cancels it when its caller exits."

  @doc "Returns the result, an exit reason, or a timeout; no worker survives cancellation."
  @spec run((-> term()), non_neg_integer()) :: {:ok, term()} | {:error, term()}
  def run(fun, timeout) when is_function(fun, 0) and is_integer(timeout) and timeout >= 0 do
    owner = self()
    token = make_ref()
    callers = [owner | Process.get(:"$callers", [])]
    {pid, monitor} = spawn_monitor(fn -> supervise(owner, token, callers, fun, timeout) end)

    receive do
      {^token, result} ->
        Process.demonitor(monitor, [:flush])
        result

      {:DOWN, ^monitor, :process, ^pid, reason} ->
        {:error, reason}
    end
  end

  # The guardian owns this linked task, traps exits, and always shuts it down.
  # A supervisor-owned unlinked task would outlive a killed caller here.
  defp supervise(owner, token, callers, fun, timeout) do
    Process.flag(:trap_exit, true)
    Process.put(:"$callers", callers)
    owner_monitor = Process.monitor(owner)
    # credo:disable-for-next-line OeditusCredo.Check.Warning.UnmanagedTask
    task = Task.async(fun)
    task_ref = task.ref

    result =
      receive do
        {^task_ref, value} -> {:ok, value}
        {:DOWN, ^task_ref, :process, _, reason} -> {:error, reason}
        {:DOWN, ^owner_monitor, :process, _, _} -> {:error, :caller_down}
      after
        timeout -> {:error, :timeout}
      end

    Task.shutdown(task, :brutal_kill)
    send(owner, {token, result})
  end
end
