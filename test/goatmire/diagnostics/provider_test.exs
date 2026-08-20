defmodule Goatmire.Diagnostics.ProviderTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.Diagnostics.Provider

  setup do
    Application.put_env(:goatmire, :diagnostics_codex_runner, Goatmire.FakeCodexRunner)
    Application.put_env(:goatmire, :diagnostics_ollama_runner, Goatmire.FakeOllamaRunner)

    on_exit(fn ->
      for key <- [
            :diagnostics_codex_runner,
            :diagnostics_ollama_runner,
            :fake_codex_result,
            :fake_ollama_result,
            :fake_codex_preflight,
            :fake_ollama_preflight
          ],
          do: Application.delete_env(:goatmire, key)
    end)

    :ok
  end

  test "uses ChatGPT-plan Codex as the primary reasoner" do
    assert {:ok, "codex diagnosis", %{provider: :codex, plan_type: "pro", reason: nil}} =
             Provider.complete([%{"role" => "user", "content" => "diagnose"}])
  end

  test "falls back visibly to Ollama when Codex is unavailable" do
    Application.put_env(:goatmire, :fake_codex_result, {:error, :codex_timeout})

    assert {:ok, "ollama diagnosis", %{provider: :ollama, reason: reason}} =
             Provider.complete([%{"role" => "user", "content" => "diagnose"}])

    assert reason =~ "timed out"
  end

  test "keeps the application alive when both reasoners fail" do
    Application.put_env(:goatmire, :fake_codex_result, {:error, :chatgpt_login_required})
    Application.put_env(:goatmire, :fake_ollama_result, {:error, :ollama_unavailable})

    assert {:error, :diagnostics_unavailable} =
             Provider.complete([%{"role" => "user", "content" => "diagnose"}])

    assert Provider.status().state == :unavailable
    assert Process.alive?(Process.whereis(Goatmire.Engine))
  end

  test "publishes Ollama readiness when Codex preflight fails" do
    Application.put_env(:goatmire, :fake_codex_preflight, {:error, :codex_not_installed})

    assert %{available: true} = Provider.refresh_status()
    assert %{state: :available, provider: :ollama, reason: reason} = Provider.status()
    assert reason =~ "not installed"
  end

  test "publishes an unavailable state when both preflights fail" do
    Application.put_env(:goatmire, :fake_codex_preflight, {:error, :codex_not_installed})
    Application.put_env(:goatmire, :fake_ollama_preflight, {:error, :ollama_unavailable})

    assert %{available: false} = Provider.refresh_status()
    assert %{state: :unavailable, provider: nil, reason: reason} = Provider.status()
    assert reason =~ "Codex"
    assert reason =~ "Ollama"
  end
end
