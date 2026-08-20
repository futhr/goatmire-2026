defmodule Goatmire.VerificationDemoTest do
  @moduledoc false
  use ExUnit.Case, async: false

  @moduletag :maude

  alias Goatmire.VerificationDemo

  test "runs the exact approval and sovereignty checks used on stage" do
    assert {:ok,
            %{
              scenario: 5,
              mode: :local_equational_check,
              maude_version: version,
              checks: %{
                missing_approval_gate: [:approval_gate_bypass],
                explicit_approval_gate: [],
                outside_jurisdiction: [:sovereignty_violation]
              },
              scope: scope
            }} = VerificationDemo.run()

    assert is_binary(version)
    assert scope =~ "current ExMaude.AI detector"
    assert %{size: 4, overflow: 0} = ExMaude.Pool.status()
  end
end
