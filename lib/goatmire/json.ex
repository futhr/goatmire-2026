defmodule Goatmire.JSON do
  @moduledoc """
  JSON admission without ambiguous object keys.

  Decodes once with ordered objects so duplicate keys remain visible until
  validation. Native objects may use atom keys, which become strings; collisions
  are rejected before either value can disappear. Scalar JSON types are kept.
  Callers own their payload size and shape limits.
  """

  @doc "Decodes JSON, rejecting duplicate keys at every object depth."
  @spec decode(iodata()) :: {:ok, term()} | {:error, term()}
  def decode(data) do
    with {:ok, value} <- Jason.decode(data, objects: :ordered_objects) do
      normalize(value)
    end
  end

  @doc "Decodes JSON for Plug, raising on invalid or ambiguous input."
  @spec decode!(iodata()) :: term()
  def decode!(data) do
    case decode(data) do
      {:ok, value} -> value
      {:error, %Jason.DecodeError{} = error} -> raise error
      {:error, reason} -> raise ArgumentError, "invalid JSON object: #{inspect(reason)}"
    end
  end

  @doc "Normalizes native JSON values and checks object-key uniqueness."
  @spec normalize(term()) :: {:ok, term()} | {:error, term()}
  def normalize(%Jason.OrderedObject{values: pairs}), do: normalize_object(pairs)
  def normalize(%_{}), do: {:error, :invalid_json_value}
  def normalize(value) when is_map(value), do: normalize_object(value)
  def normalize(value) when is_list(value), do: normalize_list(value, [])

  def normalize(value) when is_binary(value) do
    if String.valid?(value), do: {:ok, value}, else: {:error, :invalid_json_value}
  end

  def normalize(value) when is_number(value) or is_boolean(value) or is_nil(value),
    do: {:ok, value}

  def normalize(_), do: {:error, :invalid_json_value}

  defp normalize_object(pairs) do
    Enum.reduce_while(pairs, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, key} <- normalize_key(key),
           false <- Map.has_key?(acc, key),
           {:ok, value} <- normalize(value) do
        {:cont, {:ok, Map.put(acc, key, value)}}
      else
        true -> {:halt, {:error, :duplicate_key}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp normalize_key(key) when is_atom(key), do: {:ok, Atom.to_string(key)}
  defp normalize_key(key) when is_binary(key), do: normalize(key)
  defp normalize_key(_), do: {:error, :invalid_json_key}

  defp normalize_list([], acc), do: {:ok, Enum.reverse(acc)}

  defp normalize_list([value | rest], acc) do
    with {:ok, value} <- normalize(value), do: normalize_list(rest, [value | acc])
  end

  defp normalize_list(_, _), do: {:error, :invalid_json_value}
end
