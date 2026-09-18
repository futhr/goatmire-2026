defmodule Goatmire.Talk.Pairing do
  @moduledoc """
  One-time codes that join a tablet to the stage session through a QR code.

  The code is projected, so anyone in the room can scan it: each code opens
  one session, expires after five minutes, and issuing a new code invalidates
  the previous one. Without a stage token there is no remote session to join,
  so no code is issued.
  """

  use GenServer

  alias Goatmire.Config

  @topic "talk:pairing"
  @ttl_ms 300_000

  @doc "Starts the owner of the current pairing code."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "PubSub topic carrying `:talk_paired` once a code is redeemed."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc "Lifetime of one code in milliseconds."
  @spec ttl_ms() :: pos_integer()
  def ttl_ms, do: @ttl_ms

  @doc "Issues a fresh code and invalidates any earlier one."
  @spec issue() :: {:ok, String.t()} | {:error, :remote_disabled}
  def issue, do: GenServer.call(__MODULE__, :issue)

  @doc "Consumes a code; each issued code succeeds at most once."
  @spec redeem(String.t()) :: :ok | :error
  def redeem(code) when is_binary(code), do: GenServer.call(__MODULE__, {:redeem, code})

  @doc "Invalidates the current code so a closed QR overlay cannot be scanned later."
  @spec revoke() :: :ok
  def revoke, do: GenServer.call(__MODULE__, :revoke)

  @impl true
  def init(_), do: {:ok, nil}

  @impl true
  def handle_call(:issue, _, state) do
    if remote_enabled?() do
      code = Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
      {:reply, {:ok, code}, %{code: code, expires_at: now_ms() + @ttl_ms}}
    else
      {:reply, {:error, :remote_disabled}, state}
    end
  end

  def handle_call({:redeem, supplied}, _, %{code: code, expires_at: expires_at} = state)
      when byte_size(supplied) == byte_size(code) do
    cond do
      now_ms() > expires_at ->
        {:reply, :error, nil}

      :crypto.hash_equals(supplied, code) ->
        Phoenix.PubSub.broadcast(Goatmire.PubSub, @topic, :talk_paired)
        {:reply, :ok, nil}

      true ->
        {:reply, :error, state}
    end
  end

  def handle_call({:redeem, _}, _, state), do: {:reply, :error, state}
  def handle_call(:revoke, _, _), do: {:reply, :ok, nil}

  # Mirrors the unlock route: a shorter token never enables remote access.
  defp remote_enabled? do
    token = Config.talk_remote_token()
    is_binary(token) and byte_size(token) >= 12
  end

  defp now_ms, do: System.monotonic_time(:millisecond)
end
