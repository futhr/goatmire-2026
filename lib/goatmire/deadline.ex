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

  defp supervise(owner, token, callers, fun, timeout) do
    Process.flag(:trap_exit, true)
    Process.put(:"$callers", callers)
    owner_monitor = Process.monitor(owner)
    task = Task.async(fun)

    result =
      receive do
        {ref, value} when ref == task.ref -> {:ok, value}
        {:DOWN, ref, :process, _, reason} when ref == task.ref -> {:error, reason}
        {:DOWN, ^owner_monitor, :process, _, _} -> {:error, :caller_down}
      after
        timeout -> {:error, :timeout}
      end

    Task.shutdown(task, :brutal_kill)
    send(owner, {token, result})
  end
end
