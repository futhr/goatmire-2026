defmodule Goatmire.Protocol.Modbus do
  @moduledoc """
  Minimal Modbus TCP client — enough to read registers off an industrial I/O
  module.

      MBAP header (7 bytes)          PDU
      ┌────────┬────────┬────────┬──┬──────────────────┐
      │ txn id │ proto  │ length │ui│ fn │ data        │
      └────────┴────────┴────────┴──┴──────────────────┘

  Supports `0x03` read holding registers and `0x04` read input registers.
  Writes are deliberately absent: nothing here should be able to actuate a
  physical industrial output.
  """

  @read_holding 0x03
  @read_input 0x04
  @default_timeout 2_000

  @type conn :: :gen_tcp.socket()

  @doc """
  Opens a connection to a Modbus TCP device.

  ## Options

    * `:port` — default 502, the registered Modbus port
    * `:timeout` — connect timeout, default #{@default_timeout} ms
  """
  @spec connect(String.t() | :inet.ip_address(), keyword()) :: {:ok, conn()} | {:error, term()}
  def connect(host, opts \\ []) do
    port = Keyword.get(opts, :port, 502)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    host = if is_binary(host), do: String.to_charlist(host), else: host

    :gen_tcp.connect(host, port, [:binary, active: false, packet: :raw], timeout)
  end

  @doc "Closes a Modbus TCP connection."
  @spec close(conn()) :: :ok
  def close(socket), do: :gen_tcp.close(socket)

  @doc "Reads `count` input registers (function 0x04) starting at `address`."
  @spec read_input_registers(conn(), non_neg_integer(), pos_integer(), keyword()) ::
          {:ok, [non_neg_integer()]} | {:error, term()}
  def read_input_registers(socket, address, count, opts \\ []) do
    request(socket, @read_input, address, count, opts)
  end

  @doc "Reads `count` holding registers (function 0x03) starting at `address`."
  @spec read_holding_registers(conn(), non_neg_integer(), pos_integer(), keyword()) ::
          {:ok, [non_neg_integer()]} | {:error, term()}
  def read_holding_registers(socket, address, count, opts \\ []) do
    request(socket, @read_holding, address, count, opts)
  end

  defp request(socket, function, address, count, opts) do
    unit_id = Keyword.get(opts, :unit_id, 1)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    txn = :erlang.unique_integer([:positive]) |> rem(0xFFFF)

    pdu = <<function::8, address::16, count::16>>
    frame = <<txn::16, 0::16, byte_size(pdu) + 1::16, unit_id::8>> <> pdu

    with :ok <- :gen_tcp.send(socket, frame),
         {:ok, <<^txn::16, 0::16, length::16, _::8>>} <- recv(socket, 7, timeout),
         {:ok, body} <- recv(socket, length - 1, timeout) do
      decode(body, function, count)
    else
      {:ok, unexpected} -> {:error, {:unexpected_header, unexpected}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp recv(socket, bytes, timeout), do: :gen_tcp.recv(socket, bytes, timeout)

  # An exception response sets the high bit of the function code. Typed, because
  # 0x02 (illegal data address) is a wiring problem, not a network one.
  defp decode(<<function_with_error::8, code::8>>, function, _)
       when function_with_error == function + 0x80 do
    {:error, {:modbus_exception, exception(code), code}}
  end

  defp decode(<<echoed_function::8, byte_count::8, data::binary>>, function, count)
       when echoed_function == function and byte_size(data) == byte_count and
              byte_count == count * 2 do
    {:ok, for(<<register::16 <- data>>, do: register)}
  end

  defp decode(body, _, _), do: {:error, {:malformed_response, body}}

  defp exception(0x01), do: :illegal_function
  defp exception(0x02), do: :illegal_data_address
  defp exception(0x03), do: :illegal_data_value
  defp exception(0x04), do: :slave_device_failure
  defp exception(0x06), do: :slave_device_busy
  defp exception(0x0B), do: :gateway_target_failed_to_respond
  defp exception(_), do: :unknown

  @doc """
  Converts a raw register value to milliamps.

  Module-specific: 12-bit over 0–20 mA is 0..4095, 16-bit over 4–20 mA is
  0..65535. Configuration, not a constant.
  """
  @spec to_milliamps(non_neg_integer(), keyword()) :: float()
  def to_milliamps(raw, opts \\ []) do
    raw_min = Keyword.get(opts, :raw_min, 0)
    raw_max = Keyword.get(opts, :raw_max, 4095)
    ma_min = Keyword.get(opts, :ma_min, 0.0)
    ma_max = Keyword.get(opts, :ma_max, 20.0)

    span = raw_max - raw_min
    if span == 0, do: ma_min, else: ma_min + (raw - raw_min) / span * (ma_max - ma_min)
  end
end
