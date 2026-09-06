defmodule Goatmire.Diagnostics.Status do
  @moduledoc "Owns the latest provider status without persistent-term heap invalidations."
  use GenServer

  @doc "Starts the provider status owner."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Reads the last published transition; concurrent requests may interleave."
  @spec get() :: map()
  def get, do: GenServer.call(__MODULE__, :get)

  @doc "Stores one provider transition."
  @spec put(map()) :: :ok
  def put(status), do: GenServer.call(__MODULE__, {:put, status})

  @doc "Restores the idle state."
  @spec reset() :: :ok
  def reset, do: put(idle())

  @impl true
  def init(_), do: {:ok, idle()}

  @impl true
  def handle_call(:get, _, state), do: {:reply, state, state}
  def handle_call({:put, status}, _, _), do: {:reply, :ok, status}

  defp idle, do: %{state: :idle, provider: nil, model: nil, reason: nil, completed_at: nil}
end
