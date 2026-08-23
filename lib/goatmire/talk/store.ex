defmodule Goatmire.Talk.Store do
  @moduledoc """
  Owns the ETS table the presenter clock checkpoints into — a separate owner
  so the checkpoint survives a clock crash.

  Not `:persistent_term` on purpose: its docs reserve it for rarely updated
  terms, since every update copies the key table and reclaiming the old term
  forces a global GC across all process heaps. The clock checkpoints on every
  slide change, sometimes mid-storm with thousands of device processes alive.
  """

  use GenServer

  @table :goatmire_talk_clock

  @doc "Starts the checkpoint table owner."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Checkpoints the clock's saved state."
  @spec put(map()) :: :ok
  def put(saved) do
    :ets.insert(@table, {:saved, saved})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Returns the last checkpoint, or nil."
  @spec get() :: map() | nil
  def get do
    case :ets.lookup(@table, :saved) do
      [{:saved, saved}] -> saved
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  @doc "Drops the checkpoint."
  @spec clear() :: :ok
  def clear do
    :ets.delete(@table, :saved)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end
end
