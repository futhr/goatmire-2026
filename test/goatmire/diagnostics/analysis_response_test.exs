defmodule Goatmire.Diagnostics.AnalysisResponseTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Goatmire.Diagnostics.Analysis

  setup do
    keys = [:diagnostics_codex_runner, :fake_codex_result]
    saved = Map.new(keys, &{&1, Application.fetch_env(:goatmire, &1)})
    Application.put_env(:goatmire, :diagnostics_codex_runner, Goatmire.FakeCodexRunner)

    on_exit(fn ->
      for {key, value} <- saved do
        case value do
          {:ok, value} -> Application.put_env(:goatmire, key, value)
          :error -> Application.delete_env(:goatmire, key)
        end
      end
    end)

    :ok
  end

  test "provider responses must satisfy the complete strict classification schema" do
    valid = %{
      "inference" => "insufficient_evidence",
      "next_check" => "inspect_raw_metrics",
      "confidence" => "low"
    }

    for response <- [
          Jason.encode!(Map.put(valid, "extra", true)),
          Jason.encode!(Map.delete(valid, "confidence")),
          Jason.encode!(Map.put(valid, "confidence", "certain")),
          String.replace(Jason.encode!(valid), "{", ~S({"confidence":"high",), global: false)
        ] do
      set_response(response)
      assert {:error, :beamlens_failed} = analyze()
    end

    set_response(Jason.encode!(valid))
    assert {:ok, %{stage_answer: %{confidence: [:low]}}} = analyze()
  end

  defp set_response(response) do
    Application.put_env(
      :goatmire,
      :fake_codex_result,
      {:ok, response, %{provider: :codex, model: "test"}}
    )
  end

  defp analyze do
    Analysis.run("why?",
      availability: %{available: true},
      snapshot: %{current: %{verification: nil}, window: %{alerts: 12}}
    )
  end
end
