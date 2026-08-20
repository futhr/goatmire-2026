defmodule Goatmire.ConfigTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Goatmire.Config

  test "defaults describe a laptop with no broker and no fleet" do
    assert Config.transport() == Goatmire.Transport.Local
    refute Config.autostart_fleet?()
    assert Config.role() == :engine
  end

  test "diagnostics defaults use the loopback bridge and fixed local fallback" do
    assert Config.diagnostics_bridge_url() =~ "127.0.0.1"
    assert Config.diagnostics_ollama_model() == "qwen3.5:4b-q4_K_M"
    assert Config.diagnostics_codex_model() == nil
  end

  test "rule generation uses the checked-in model tag" do
    assert Config.llm_model!() == "test-model"
  end
end
