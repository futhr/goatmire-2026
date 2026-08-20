defmodule Goatmire.CIPolicyTest do
  @moduledoc false

  use ExUnit.Case, async: true

  test "real local-model tests are never enabled by CI" do
    workflow = File.read!(".github/workflows/quality.yml")

    refute workflow =~ "mix test.llm"
    refute workflow =~ "--only llm"
    refute workflow =~ "--include llm"
  end
end
