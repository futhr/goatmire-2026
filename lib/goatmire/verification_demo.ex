defmodule Goatmire.VerificationDemo do
  @moduledoc """
  Runs Scenario 5's three deterministic `ExMaude.AI` checks: missing approval,
  explicit approval, and an invalid jurisdiction.
  """

  @type result :: %{
          scenario: 5,
          mode: :local_equational_check,
          maude_version: String.t(),
          checks: %{
            missing_approval_gate: [atom()],
            explicit_approval_gate: [atom()],
            outside_jurisdiction: [atom()]
          },
          scope: String.t()
        }

  @doc """
  Executes the three deterministic checks and rejects unexpected demo drift.
  """
  @spec run() :: {:ok, result()} | {:error, term()}
  def run do
    with {:ok, version} <- ExMaude.version(),
         {:ok, missing_gate} <-
           ExMaude.AI.detect_conflicts(unsafe_policy(), jurisdictions: [:eu]),
         {:ok, explicit_gate} <-
           ExMaude.AI.detect_conflicts(gated_policy(), jurisdictions: [:eu]),
         {:ok, outside_jurisdiction} <-
           ExMaude.AI.detect_conflicts(sovereignty_policy(), jurisdictions: [:eu, :ch]),
         checks = %{
           missing_approval_gate: conflict_types(missing_gate),
           explicit_approval_gate: conflict_types(explicit_gate),
           outside_jurisdiction: conflict_types(outside_jurisdiction)
         },
         :ok <- validate_expected_checks(checks) do
      {:ok,
       %{
         scenario: 5,
         mode: :local_equational_check,
         maude_version: version,
         checks: checks,
         scope:
           "Clean means no conflict represented by the current ExMaude.AI detector was found."
       }}
    end
  end

  defp unsafe_policy do
    [
      %{
        id: "autodose-controller",
        agent_id: {"acme", "controller"},
        trigger: {:always},
        invocations: [{:invoke_tool, "dose", %{}, "high_impact", :eu}]
      }
    ]
  end

  defp gated_policy do
    [
      %{
        id: "autodose-controller",
        agent_id: {"acme", "controller"},
        trigger: {:always},
        invocations: [
          {:require_approval, "dosing_high_delta"},
          {:invoke_tool, "dose", %{}, "high_impact", :eu}
        ]
      }
    ]
  end

  defp sovereignty_policy do
    [
      %{
        id: "research-assistant",
        agent_id: {"acme", "researcher"},
        trigger: {:always},
        invocations: [{:invoke_tool, "search", %{}, "internet_access", :us}]
      }
    ]
  end

  defp conflict_types(conflicts) do
    conflicts
    |> Enum.map(& &1.type)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp validate_expected_checks(%{
         missing_approval_gate: [:approval_gate_bypass],
         explicit_approval_gate: [],
         outside_jurisdiction: [:sovereignty_violation]
       }),
       do: :ok

  defp validate_expected_checks(checks), do: {:error, {:unexpected_verification_results, checks}}
end
