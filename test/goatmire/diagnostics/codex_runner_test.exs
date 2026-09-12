defmodule Goatmire.Diagnostics.CodexRunnerTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.Diagnostics.CodexRunner

  setup do
    directory =
      Path.join(
        System.tmp_dir!(),
        "goatmire-fake-codex-#{System.unique_integer([:positive, :monotonic])}"
      )

    script = Path.join(directory, "codex")
    File.mkdir!(directory)

    File.write!(script, """
    #!/bin/sh
    while IFS= read -r line; do
      case "$line" in
        *'"method":"initialize"'*)
          printf '%s\n' '{"id":1,"result":{"serverInfo":{"name":"fake"}}}'
          ;;
        *'"method":"account/read"'*)
          printf '%s\n' '{"id":2,"result":{"account":{"type":"chatgpt","planType":"pro"}}}'
          ;;
        *'"method":"account/rateLimits/read"'*)
          printf '%s\n' '{"id":3,"result":{"rateLimits":{"primary":{"usedPercent":12,"resetsAt":123},"rateLimitReachedType":null,"spendControlReached":false}}}'
          ;;
        *'"method":"config/read"'*)
          printf '%s\n' '{"id":7,"result":{"config":{"mcp_servers":{"example":{"enabled":true}},"plugins":{}}}}'
          ;;
        *'"method":"mcpServerStatus/list"'*)
          printf '%s\n' '{"id":6,"result":{"data":[]}}'
          ;;
        *'"method":"thread/start"'*)
          printf '%s\n' '{"id":4,"result":{"thread":{"id":"thread-1"},"model":"gpt-test"}}'
          ;;
        *'"method":"turn/start"'*)
          printf '%s\n' '{"id":5,"result":{"turn":{"id":"turn-1"}}}'
          printf '%s\n' '{"method":"item/completed","params":{"threadId":"thread-1","item":{"type":"agentMessage","text":"{\\"summary\\":\\"grounded\\"}"}}}'
          printf '%s\n' '{"method":"thread/tokenUsage/updated","params":{"threadId":"thread-1","tokenUsage":{"total":{"inputTokens":20,"cachedInputTokens":5,"outputTokens":7}}}}'
          printf '%s\n' '{"method":"turn/completed","params":{"threadId":"thread-1","turn":{"status":"completed"}}}'
          ;;
      esac
    done
    """)

    File.chmod!(script, 0o700)

    on_exit(fn ->
      File.rm(script)
      File.rmdir(directory)
    end)

    {:ok, executable: script}
  end

  test "diagnostic processes disable execution, connectors and inherited MCP servers" do
    args = CodexRunner.launch_args()
    assert "shell_tool" in args
    assert "apps" in args
    assert "browser_use" in args
    assert "mcp_servers={}" in args
    assert "plugins={}" in args
    assert "project_doc_max_bytes=0" in args
  end

  test "a timed-out turn leaves no app server process behind" do
    directory =
      Path.join(
        System.tmp_dir!(),
        "goatmire-orphan-codex-" <> Base.encode16(:crypto.strong_rand_bytes(6))
      )

    File.mkdir!(directory)
    script = Path.join(directory, "codex")
    pidfile = Path.join(directory, "child.pid")
    on_exit(fn -> File.rm_rf!(directory) end)

    # An app server that ignores stdin EOF, which closing the port alone cannot stop.
    File.write!(script, """
    #!/bin/sh
    echo $$ > #{pidfile}
    while true; do sleep 1; done
    """)

    File.chmod!(script, 0o700)

    # Capture the child while it is still running, so a slow host delays the
    # check instead of racing it.
    watcher = Task.async(fn -> await_pidfile(pidfile, deadline(5_000)) end)

    assert {:error, :codex_timeout} =
             CodexRunner.complete([%{"role" => "user", "content" => "hi"}],
               executable: script,
               timeout: 1_000
             )

    os_pid = Task.await(watcher, 6_000)

    assert is_binary(os_pid),
           "the fake app server never started, so the orphan check could not run"

    on_exit(fn ->
      if running?(os_pid), do: signal(os_pid, "-KILL")
    end)

    assert await_exit(os_pid, deadline(5_000)) == :ok
  end

  defp deadline(ms), do: System.monotonic_time(:millisecond) + ms

  defp await_pidfile(pidfile, deadline) do
    case File.read(pidfile) do
      {:ok, contents} when byte_size(contents) > 0 ->
        String.trim(contents)

      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(10)
          await_pidfile(pidfile, deadline)
        end
    end
  end

  # Generous upper bound on signalling and reaping, not a latency assertion: an
  # unsignalled child loops for ever, so it never leaves this wait.
  defp await_exit(os_pid, deadline) do
    cond do
      not running?(os_pid) -> :ok
      System.monotonic_time(:millisecond) >= deadline -> {:error, :still_running}
      true -> Process.sleep(25) && await_exit(os_pid, deadline)
    end
  end

  defp running?(os_pid) do
    {_, status} = signal(os_pid, "-0")
    status == 0
  end

  # No environment for the child: it only needs to name a pid.
  defp signal(os_pid, flag) do
    System.cmd("kill", [flag, os_pid],
      env: Enum.map(System.get_env(), fn {name, _} -> {name, nil} end),
      stderr_to_stdout: true
    )
  end

  test "runs one ephemeral app-server completion and returns compact usage", %{executable: script} do
    assert {:ok, ~s({"summary":"grounded"}), metadata} =
             CodexRunner.complete(
               [%{"role" => "user", "content" => "diagnose the bounded snapshot"}],
               executable: script,
               output_schema: %{"type" => "object"},
               timeout: 1_000
             )

    assert metadata.provider == :codex
    assert metadata.model == "gpt-test"
    assert metadata.plan_type == "pro"
    assert metadata.quota.used_percent == 12
    assert metadata.usage == %{input_tokens: 20, cached_input_tokens: 5, output_tokens: 7}
  end

  test "refuses a remaining MCP capability before starting a model turn", %{executable: script} do
    contents =
      File.read!(script)
      |> String.replace(
        ~s({"data":[]}),
        ~s({"data":[{"tools":{"danger":{}},"resources":[],"resourceTemplates":[]}]})
      )

    File.write!(script, contents)

    assert {:error, :diagnostic_tools_available} =
             CodexRunner.complete([], executable: script, timeout: 1_000)
  end

  test "preflight reads plan auth and quota without starting a turn", %{executable: script} do
    assert {:ok, %{plan_type: "pro", quota: %{used_percent: 12}}} =
             CodexRunner.preflight(executable: script, timeout: 1_000)
  end

  test "accepts ChatGPT plan auth without retaining the account identity" do
    assert {:ok, %{plan_type: "pro"}} =
             CodexRunner.authorize_account(%{
               "account" => %{
                 "type" => "chatgpt",
                 "planType" => "pro",
                 "email" => "private@example.test"
               }
             })
  end

  test "refuses API-key auth so diagnostics cannot create token-billed usage" do
    assert {:error, :api_key_auth_refused} =
             CodexRunner.authorize_account(%{"account" => %{"type" => "apiKey"}})
  end

  test "rejects missing login and malformed rate-limit responses" do
    assert {:error, :chatgpt_login_required} = CodexRunner.authorize_account(%{})
    assert {:error, :rate_limits_unavailable} = CodexRunner.authorize_quota(%{})
  end

  test "rejects unknown, secondary-exhausted and bucket-exhausted quota" do
    available = %{"primary" => %{"usedPercent" => 10}}

    for payload <- [
          %{"rateLimits" => %{}},
          %{"rateLimits" => Map.put(available, "secondary", %{"usedPercent" => 100})},
          %{
            "rateLimits" => available,
            "rateLimitsByLimitId" => %{"other" => %{"primary" => %{"usedPercent" => 100}}}
          }
        ] do
      assert {:error, _} = CodexRunner.authorize_quota(payload)
    end
  end

  test "rejects depleted plan quota and accepts available quota" do
    assert {:error, :chatgpt_plan_quota_unavailable} =
             CodexRunner.authorize_quota(%{
               "rateLimits" => %{
                 "primary" => %{"usedPercent" => 100},
                 "rateLimitReachedType" => "primary"
               }
             })

    assert {:ok, %{used_percent: 28, resets_at: 123}} =
             CodexRunner.authorize_quota(%{
               "rateLimits" => %{
                 "primary" => %{"usedPercent" => 28, "resetsAt" => 123},
                 "rateLimitReachedType" => nil
               }
             })
  end
end
