defmodule Goatmire.JSONTest do
  @moduledoc false
  use ExUnit.Case, async: true

  test "rejects duplicate keys including escaped spellings and nested objects" do
    for json <- [~S({"x":1,"x":2}), ~S({"x":1,"\u0078":2}), ~S({"a":[{"x":false,"x":null}]})] do
      assert {:error, :duplicate_key} = Goatmire.JSON.decode(json)
      assert_raise ArgumentError, fn -> Goatmire.JSON.decode!(json) end
    end
  end

  test "preserves JSON types through one decode" do
    assert {:ok, value} = Goatmire.JSON.decode(~S({"a":[1,1.0,true,false,null,"1",{},[]]}))
    assert value === %{"a" => [1, 1.0, true, false, nil, "1", %{}, []]}
  end

  test "native normalization accepts atom keys without collisions or scalar coercion" do
    assert {:ok, normalized} = Goatmire.JSON.normalize(%{items: [%{x: 1.0}], enabled: false})
    assert normalized === %{"items" => [%{"x" => 1.0}], "enabled" => false}
    assert {:error, :duplicate_key} = Goatmire.JSON.normalize(%{items: [%{:x => 1, "x" => 2}]})

    for invalid <- [self(), :other, {1, 2}, [1 | 2], %{1 => "x"}, %{<<255>> => 1}, <<255>>] do
      assert {:error, _} = Goatmire.JSON.normalize(invalid)
    end
  end

  test "malformed JSON retains the decoder error" do
    assert {:error, %Jason.DecodeError{}} = Goatmire.JSON.decode("{")
    assert_raise Jason.DecodeError, fn -> Goatmire.JSON.decode!("{") end
  end
end
