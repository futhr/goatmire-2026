defmodule GoatmireWeb.ControllersTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Plug.Conn

  alias Goatmire.{Engine, StubVerifier}

  @endpoint GoatmireWeb.Endpoint

  setup do
    Application.put_env(:goatmire, :verifier, StubVerifier)
    Application.put_env(:goatmire, :diagnostics_codex_runner, Goatmire.FakeCodexRunner)
    Application.put_env(:goatmire, :diagnostics_ollama_runner, Goatmire.FakeOllamaRunner)
    StubVerifier.reset()
    :ok = Engine.reset()

    on_exit(fn ->
      Application.delete_env(:goatmire, :verifier)
      Application.delete_env(:goatmire, :diagnostics_codex_runner)
      Application.delete_env(:goatmire, :diagnostics_ollama_runner)
    end)

    :ok
  end

  test "health reports each capability separately" do
    conn = get(build_conn(), "/api/health")
    body = json_response(conn, 200)

    assert body["maude"] == %{"status" => "ok", "detail" => "stub"}
    assert body["transport"] =~ "Goatmire.Transport.Local"
    assert is_integer(body["fleet"]["devices"])
    assert body["engine"]["counters"] == %{"alerts" => 0, "events" => 0, "throttled" => 0}
  end

  test "HTTP telemetry ingress reaches the engine" do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/api/things/http-agv/telemetry", %{"property" => "battery", "value" => 18})

    assert %{"status" => "accepted", "thing_id" => "http-agv"} = json_response(conn, 200)
    assert_eventually(fn -> Engine.properties("http-agv")["battery"] == 18 end)
  end

  test "HTTP telemetry ingress rejects an incomplete body" do
    conn = post(build_conn(), "/api/things/http-agv/telemetry", %{"property" => "battery"})
    assert %{"error" => error} = json_response(conn, 422)
    assert error =~ "property"
  end

  test "browser responses carry the repository CSP" do
    conn = get(build_conn(), "/")
    [csp] = get_resp_header(conn, "content-security-policy")

    assert csp =~ "default-src 'self'"
    assert csp =~ "frame-ancestors 'none'"
  end

  test "loopback BAML completion requests receive OpenAI-compatible JSON" do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/api/internal/diagnostics/v1/chat/completions", %{
        "model" => "goatmire-diagnostics",
        "stream" => false,
        "messages" => [%{"role" => "user", "content" => "diagnose"}]
      })

    assert %{
             "object" => "chat.completion",
             "choices" => [%{"message" => %{"content" => "codex diagnosis"}}]
           } = json_response(conn, 200)
  end

  test "the completion bridge rejects non-loopback callers" do
    conn = %{build_conn() | remote_ip: {192, 0, 2, 10}}

    conn =
      post(conn, "/api/internal/diagnostics/v1/chat/completions", %{
        "messages" => [%{"role" => "user", "content" => "diagnose"}]
      })

    assert json_response(conn, 403)["error"]["message"] =~ "loopback-only"
  end

  defp assert_eventually(fun, attempts \\ 20)
  defp assert_eventually(fun, 0), do: assert(fun.())

  defp assert_eventually(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end
end
