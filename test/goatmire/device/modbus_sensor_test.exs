defmodule Goatmire.Device.ModbusSensorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Goatmire.Device.ModbusSensor
  alias Goatmire.Protocol.Modbus

  describe "classify/1 — NAMUR NE 43" do
    test "a dead loop is a wire break, not a zero reading" do
      assert ModbusSensor.classify(0.0) == :wire_break
      assert ModbusSensor.classify(3.6) == :wire_break
    end

    test "the live zero is a valid measurement" do
      assert ModbusSensor.classify(4.0) == :ok
    end

    test "the gap between the failure threshold and the range is under-range" do
      assert ModbusSensor.classify(3.7) == :under_range
    end

    test "the top of the range and its margin" do
      assert ModbusSensor.classify(20.0) == :ok
      assert ModbusSensor.classify(20.5) == :ok
      assert ModbusSensor.classify(20.8) == :over_range
      assert ModbusSensor.classify(21.0) == :short_circuit
      assert ModbusSensor.classify(24.0) == :short_circuit
    end

    test "0 mA and 4 mA are never the same answer" do
      refute ModbusSensor.classify(0.0) == ModbusSensor.classify(4.0)
    end
  end

  describe "to_engineering/3" do
    test "4 mA is the bottom of the range and 20 mA the top" do
      assert ModbusSensor.to_engineering(4.0, 0.0, 10.0) == 0.0
      assert ModbusSensor.to_engineering(20.0, 0.0, 10.0) == 10.0
    end

    test "midscale" do
      assert ModbusSensor.to_engineering(12.0, 0.0, 10.0) == 5.0
    end

    test "handles a range that does not start at zero" do
      assert ModbusSensor.to_engineering(4.0, -40.0, 120.0) == -40.0
      assert ModbusSensor.to_engineering(20.0, -40.0, 120.0) == 120.0
    end
  end

  describe "Modbus.to_milliamps/2" do
    test "12-bit module spanning 0–20 mA" do
      assert Modbus.to_milliamps(0, raw_min: 0, raw_max: 4095, ma_min: 0.0, ma_max: 20.0) == 0.0

      assert_in_delta Modbus.to_milliamps(4095,
                        raw_min: 0,
                        raw_max: 4095,
                        ma_min: 0.0,
                        ma_max: 20.0
                      ),
                      20.0,
                      0.001
    end

    test "16-bit module spanning 4–20 mA" do
      assert Modbus.to_milliamps(0, raw_min: 0, raw_max: 65_535, ma_min: 4.0, ma_max: 20.0) == 4.0
    end

    test "a zero span does not divide by zero" do
      assert Modbus.to_milliamps(10, raw_min: 5, raw_max: 5, ma_min: 4.0, ma_max: 20.0) == 4.0
    end
  end

  describe "end to end" do
    test "a broken wire never becomes an engineering zero" do
      raw = 0
      ma = Modbus.to_milliamps(raw, raw_min: 0, raw_max: 4095, ma_min: 0.0, ma_max: 20.0)

      assert ModbusSensor.classify(ma) == :wire_break

      # Scaled anyway it reads below range — a negative pressure on a 0–10 bar
      # sensor.
      assert ModbusSensor.to_engineering(ma, 0.0, 10.0) < 0.0
    end
  end

  describe "Modbus TCP wire protocol" do
    test "reads input and holding registers from a TCP endpoint" do
      assert {:ok, [123, 456]} = request_from_fake_device(0x04, <<0x04, 4, 123::16, 456::16>>)
      assert {:ok, [321]} = request_from_fake_device(0x03, <<0x03, 2, 321::16>>)
    end

    test "returns typed Modbus exceptions" do
      assert {:error, {:modbus_exception, :illegal_data_address, 0x02}} =
               request_from_fake_device(0x04, <<0x84, 0x02>>)
    end

    test "rejects malformed response bodies" do
      assert {:error, {:malformed_response, <<0x04, 1, 0>>}} =
               request_from_fake_device(0x04, <<0x04, 1, 0>>)
    end
  end

  defp request_from_fake_device(function, body) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, {_, port}} = :inet.sockname(listener)

    server =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listener)
        {:ok, request} = :gen_tcp.recv(socket, 12, 1_000)

        <<transaction::16, 0::16, 6::16, unit_id::8, ^function::8, _::16, _::16>> =
          request

        response = <<transaction::16, 0::16, byte_size(body) + 1::16, unit_id::8>> <> body
        :ok = :gen_tcp.send(socket, response)
        :gen_tcp.close(socket)
        :gen_tcp.close(listener)
      end)

    {:ok, socket} = Modbus.connect({127, 0, 0, 1}, port: port, timeout: 1_000)

    result =
      case function do
        0x03 -> Modbus.read_holding_registers(socket, 0, div(byte_size(body) - 2, 2))
        0x04 -> Modbus.read_input_registers(socket, 0, max(div(byte_size(body) - 2, 2), 1))
      end

    :ok = Modbus.close(socket)
    Task.await(server)
    result
  end
end
