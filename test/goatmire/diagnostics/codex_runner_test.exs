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
