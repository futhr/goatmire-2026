defmodule Goatmire.Diagnostics.OllamaTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.Diagnostics.Ollama

  setup do
    Application.put_env(:goatmire, :diagnostics_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn -> Application.delete_env(:goatmire, :diagnostics_req_options) end)
    :ok
  end

  test "preflight requires the configured fixed model" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/v1/models"

      Req.Test.json(conn, %{
        "data" => [%{"id" => "qwen3.5:4b-q4_K_M"}, %{"id" => "another-model"}]
      })
    end)

    assert {:ok, %{model: "qwen3.5:4b-q4_K_M"}} = Ollama.preflight()
  end

  test "preflight reports when the fixed model is absent" do
    Req.Test.stub(__MODULE__, fn conn -> Req.Test.json(conn, %{"data" => []}) end)

    assert {:error, {:ollama_model_missing, "qwen3.5:4b-q4_K_M"}} = Ollama.preflight()
  end

  test "completion sends a non-streaming, no-thinking request" do
    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      request = Jason.decode!(body)

      assert request["model"] == "qwen3.5:4b-q4_K_M"
      assert request["stream"] == false
      assert request["reasoning_effort"] == "none"
      assert request["max_tokens"] == 320
      assert request["messages"] == [%{"role" => "user", "content" => "diagnose"}]

      Req.Test.json(conn, %{
        "choices" => [%{"message" => %{"content" => "local diagnosis"}}]
      })
    end)

    assert {:ok, "local diagnosis", %{provider: :ollama, model: "qwen3.5:4b-q4_K_M"}} =
             Ollama.complete([%{"role" => "user", "content" => "diagnose"}])
  end

  test "completion rejects malformed and non-success responses" do
    Req.Test.stub(__MODULE__, fn conn -> Req.Test.json(conn, %{"choices" => []}) end)
    assert {:error, :invalid_ollama_response} = Ollama.complete([])

    Req.Test.stub(__MODULE__, fn conn -> conn |> Plug.Conn.send_resp(503, "offline") end)
    assert {:error, {:ollama_http_status, 503}} = Ollama.complete([])
  end
end
