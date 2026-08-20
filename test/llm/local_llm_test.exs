defmodule Goatmire.LocalLLMTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.AI.RuleGenerator
  alias Goatmire.Diagnostics.Ollama

  @moduletag :llm
  @moduletag timeout: 180_000

  setup do
    base_url = Application.fetch_env!(:goatmire, :llm_test_base_url)
    model = Application.fetch_env!(:goatmire, :llm_test_model)
    assert_loopback!(base_url)

    saved = %{
      llm_base_url: Application.get_env(:goatmire, :llm_base_url),
      llm_model: Application.get_env(:goatmire, :llm_model),
      req_options: Application.get_env(:goatmire, :req_options),
      diagnostics_base_url: Application.get_env(:goatmire, :diagnostics_ollama_base_url),
      diagnostics_model: Application.get_env(:goatmire, :diagnostics_ollama_model),
      diagnostics_req_options: Application.get_env(:goatmire, :diagnostics_req_options)
    }

    Application.put_env(:goatmire, :llm_base_url, base_url)
    Application.put_env(:goatmire, :llm_model, model)
    Application.delete_env(:goatmire, :req_options)
    Application.put_env(:goatmire, :diagnostics_ollama_base_url, base_url)
    Application.put_env(:goatmire, :diagnostics_ollama_model, model)
    Application.delete_env(:goatmire, :diagnostics_req_options)

    on_exit(fn -> restore(saved) end)
    :ok
  end

  @tag :maude
  test "the local model emits typed rules that the deterministic verifier can inspect" do
    assert {:ok, %{passes: [_ | _] = passes, final_status: status}} =
             RuleGenerator.run(
               "Route a high-impact reassignment through explicit operator approval in the EU.",
               max_attempts: 2
             )

    assert status in [:clean, :conflicts]
    assert Enum.all?(passes, &(&1.rules != []))

    assert Enum.all?(passes, fn pass -> match?({:ok, _}, RuleGenerator.decode_rules(pass.raw)) end)
  end

  test "the local diagnostic model honours a strict JSON schema" do
    schema = %{
      "type" => "object",
      "properties" => %{"state" => %{"type" => "string", "enum" => ["healthy"]}},
      "required" => ["state"],
      "additionalProperties" => false
    }

    response_format = %{
      "type" => "json_schema",
      "json_schema" => %{"name" => "local_llm_health", "strict" => true, "schema" => schema}
    }

    assert {:ok, content, %{provider: :ollama}} =
             Ollama.complete(
               [
                 %{"role" => "system", "content" => "Return only the requested JSON."},
                 %{"role" => "user", "content" => "Classify this input as healthy."}
               ],
               response_format: response_format,
               max_tokens: 40,
               timeout: 60_000
             )

    assert Jason.decode!(content) == %{"state" => "healthy"}
  end

  defp assert_loopback!(base_url) do
    host = URI.parse(base_url).host

    unless host in ["127.0.0.1", "localhost", "::1"] do
      raise "real :llm tests are local-only; got #{inspect(base_url)}"
    end
  end

  defp restore(saved) do
    restore_env(:llm_base_url, saved.llm_base_url)
    restore_env(:llm_model, saved.llm_model)
    restore_env(:req_options, saved.req_options)
    restore_env(:diagnostics_ollama_base_url, saved.diagnostics_base_url)
    restore_env(:diagnostics_ollama_model, saved.diagnostics_model)
    restore_env(:diagnostics_req_options, saved.diagnostics_req_options)
  end

  defp restore_env(key, nil), do: Application.delete_env(:goatmire, key)
  defp restore_env(key, value), do: Application.put_env(:goatmire, key, value)
end
