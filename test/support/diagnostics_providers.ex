defmodule Goatmire.FakeCodexRunner do
  @moduledoc false

  @doc false
  @spec complete([map()], keyword()) :: {:ok, String.t(), map()} | {:error, term()}
  def complete(_, _) do
    Application.get_env(
      :goatmire,
      :fake_codex_result,
      {:ok, "codex diagnosis",
       %{provider: :codex, model: "test-codex", plan_type: "pro", quota: %{used_percent: 1}}}
    )
  end

  @doc false
  @spec preflight() :: {:ok, map()} | {:error, term()}
  def preflight do
    Application.get_env(
      :goatmire,
      :fake_codex_preflight,
      {:ok, %{plan_type: "pro", quota: %{used_percent: 1}}}
    )
  end
end

defmodule Goatmire.FakeOllamaRunner do
  @moduledoc false

  @doc false
  @spec complete([map()], keyword()) :: {:ok, String.t(), map()} | {:error, term()}
  def complete(_, _) do
    Application.get_env(
      :goatmire,
      :fake_ollama_result,
      {:ok, "ollama diagnosis", %{provider: :ollama, model: "test-ollama"}}
    )
  end

  @doc false
  @spec preflight() :: {:ok, map()} | {:error, term()}
  def preflight do
    Application.get_env(
      :goatmire,
      :fake_ollama_preflight,
      {:ok, %{model: "test-ollama"}}
    )
  end
end
