defmodule Goatmire.AI.RuleGenerator do
  @moduledoc """
  Turns a sentence of English into `ExMaude.AI` rule terms, checks them, and
  feeds any conflict back for a revision.

  Reaches the configured local model over the OpenAI-compatible
  `/v1/chat/completions` surface.

  The loop verifies the *emitted rule set*, never the model. A clean second
  pass means the revision contains no conflict of the seven types
  `ExMaude.AI` models — not that the model is reliable. Generation is
  non-deterministic; the second pass can fail.
  """

  require Logger

  alias Goatmire.Config

  @type transcript :: %{
          prompt: String.t(),
          passes: [pass()],
          final_status: :clean | :conflicts | :unverified | :generation_failed
        }

  @type pass :: %{
          attempt: pos_integer(),
          rules: [map()],
          conflicts: [map()],
          status: :clean | :conflicts | :unverified,
          duration_us: non_neg_integer(),
          raw: String.t()
        }

  @system_prompt """
  You translate warehouse automation requests into a JSON rule set for an
  agent orchestrator. Reply with JSON only — no prose, no code fences.

  Schema:
  {"rules":[{
    "id": "kebab-case-id",
    "agent": "short-agent-name",
    "trigger": {"type":"always"} | {"type":"prop_lt","property":"name","value":123},
    "invocations": [
      {"type":"require_approval","class":"short_class_name"},
      {"type":"invoke_tool","name":"tool_name","args":{},
       "capability":"capability_name","jurisdiction":"eu"}
    ],
    "capability_grants": ["capability_name"],
    "authority_required": 0,
    "priority": 1
  }]}

  Rules:
  - "jurisdiction" is one of: eu, us, ch.
  - An invocation whose capability is high impact should be preceded by a
    require_approval invocation in the same rule.
  - Emit between one and three rules.
  """

  @doc """
  Generates a rule set, verifies it, and revises once per conflict round.

  ## Options

    * `:max_attempts` — how many generate→verify rounds (default 2)
    * `:jurisdictions` — allowed jurisdiction atoms (default `[:eu]`)
    * `:tenant` — tenant string for the agent id (default `"goatmire"`)
  """
  @spec run(String.t(), keyword()) :: {:ok, transcript()} | {:error, term()}
  def run(prompt, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 2)
    jurisdictions = Keyword.get(opts, :jurisdictions, [:eu])
    tenant = Keyword.get(opts, :tenant, "goatmire")
    initial = [%{role: "system", content: @system_prompt}, %{role: "user", content: prompt}]

    context = %{
      max_attempts: max_attempts,
      jurisdictions: jurisdictions,
      tenant: tenant
    }

    run_attempts(initial, prompt, context)
  end

  defp run_attempts(initial, prompt, context) do
    case attempt(initial, 1, [], context) do
      {:ok, passes} ->
        {:ok,
         %{
           prompt: prompt,
           passes: Enum.reverse(passes),
           final_status: final_status(passes)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp final_status([%{status: status} | _]), do: status
  defp final_status([]), do: :generation_failed

  defp attempt(_, attempt, passes, %{max_attempts: max_attempts})
       when attempt > max_attempts do
    {:ok, passes}
  end

  defp attempt(messages, attempt, passes, context) do
    with {:ok, raw} <- complete(messages),
         {:ok, rules} <- decode_rules(raw, context.tenant) do
      started_at = System.monotonic_time()
      {status, conflicts} = verify(rules, context.jurisdictions)
      duration_us = elapsed_us(started_at)

      pass = %{
        attempt: attempt,
        rules: rules,
        conflicts: conflicts,
        status: status,
        duration_us: duration_us,
        raw: raw
      }

      passes = [pass | passes]

      if status == :conflicts and attempt < context.max_attempts do
        messages
        |> Kernel.++([
          %{role: "assistant", content: raw},
          %{role: "user", content: revision_prompt(conflicts)}
        ])
        |> attempt(attempt + 1, passes, context)
      else
        {:ok, passes}
      end
    end
  end

  defp verify(rules, jurisdictions) do
    case ExMaude.AI.detect_conflicts(rules, jurisdictions: jurisdictions) do
      {:ok, []} -> {:clean, []}
      {:ok, conflicts} -> {:conflicts, conflicts}
      {:error, reason} -> {:unverified, [%{type: :unverified, reason: inspect(reason)}]}
    end
  rescue
    error -> {:unverified, [%{type: :unverified, reason: Exception.message(error)}]}
  catch
    :exit, reason -> {:unverified, [%{type: :unverified, reason: inspect(reason)}]}
  end

  defp revision_prompt(conflicts) do
    findings =
      Enum.map_join(conflicts, "\n", fn conflict ->
        "- #{conflict[:type]} on rule #{inspect(conflict[:rule1])}: #{conflict[:reason]}"
      end)

    """
    A formal verifier rejected that rule set. Findings:

    #{findings}

    Emit a corrected rule set in the same JSON schema. Fix only what the
    findings name; do not restate the prose.
    """
  end

  defp complete(messages) do
    body = %{
      model: Config.llm_model!(),
      messages: messages,
      temperature: 0.2,
      stream: false
    }

    response =
      :telemetry.span([:goatmire, :ai, :http], %{operation: :generate_rules}, fn ->
        result =
          [
            base_url: Config.llm_base_url(),
            url: "/chat/completions",
            method: :post,
            json: body,
            receive_timeout: Config.llm_timeout_ms(),
            retry: false,
            finch: [name: Goatmire.Finch]
          ]
          |> Keyword.merge(Application.get_env(:goatmire, :req_options, []))
          |> Req.new()
          |> Req.request()

        {result, llm_response_metadata(result)}
      end)

    case response do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        extract_content(body)

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("llm: HTTP #{status} — #{inspect(body)}")
        {:error, {:llm_http_error, status}}

      {:error, reason} ->
        Logger.error("llm: transport failure — #{inspect(reason)}")
        {:error, {:llm_unreachable, reason}}
    end
  end

  defp llm_response_metadata({:ok, %{status: status}}), do: %{status: status}
  defp llm_response_metadata({:error, _}), do: %{status: :transport_error}

  defp extract_content(%{"choices" => [%{"message" => %{"content" => content}} | _]})
       when is_binary(content) do
    {:ok, content}
  end

  defp extract_content(body), do: {:error, {:unexpected_llm_response, body}}

  @doc """
  Decodes the model's JSON into `ExMaude.AI` rule maps.

  Exposed because the Livebook shows the decode step separately: the audience
  should see that the verifier is fed a typed term, not a blob of model text.
  """
  @spec decode_rules(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def decode_rules(raw, tenant \\ "goatmire") do
    with {:ok, json} <- Jason.decode(strip_fences(raw)),
         %{"rules" => rules} when is_list(rules) <- json do
      {:ok, Enum.map(rules, &decode_rule(&1, tenant))}
    else
      {:error, %Jason.DecodeError{} = error} -> {:error, {:invalid_json, error}}
      other -> {:error, {:unexpected_rule_payload, other}}
    end
  rescue
    error -> {:error, {:undecodable_rule, error}}
  end

  defp decode_rule(rule, tenant) do
    invocations =
      rule
      |> Map.get("invocations", [])
      |> Enum.map(&decode_invocation/1)

    %{
      id: Map.get(rule, "id", "generated-rule"),
      agent_id: {tenant, Map.get(rule, "agent", "agent")},
      trigger: decode_trigger(Map.get(rule, "trigger")),
      invocations: invocations,
      capability_grants: Map.get(rule, "capability_grants", []),
      authority_required: Map.get(rule, "authority_required", 0),
      priority: Map.get(rule, "priority", 1)
    }
  end

  defp decode_trigger(%{"type" => "always"}), do: {:always}
  defp decode_trigger(%{"type" => "prop_eq", "property" => p, "value" => v}), do: {:prop_eq, p, v}
  defp decode_trigger(%{"type" => "prop_lt", "property" => p, "value" => v}), do: {:prop_lt, p, v}
  defp decode_trigger(%{"type" => "prop_gt", "property" => p, "value" => v}), do: {:prop_gt, p, v}

  defp decode_trigger(%{"type" => "prop_gte", "property" => p, "value" => v}),
    do: {:prop_gte, p, v}

  defp decode_trigger(%{"type" => "prop_lte", "property" => p, "value" => v}),
    do: {:prop_lte, p, v}

  defp decode_trigger(_), do: {:always}

  defp decode_invocation(%{"type" => "require_approval"} = invocation) do
    {:require_approval, Map.get(invocation, "class", "unclassified")}
  end

  defp decode_invocation(%{"type" => "invoke_tool"} = invocation) do
    jurisdiction =
      invocation
      |> Map.get("jurisdiction", "eu")
      |> to_jurisdiction()

    {:invoke_tool, Map.get(invocation, "name", "tool"), Map.get(invocation, "args", %{}),
     Map.get(invocation, "capability", "unspecified"), jurisdiction}
  end

  defp decode_invocation(other), do: {:require_approval, "unrecognised:#{inspect(other)}"}

  # Closed enumeration on purpose: an unknown jurisdiction string must not
  # become a new atom, and it must not silently pass the sovereignty check.
  defp to_jurisdiction("eu"), do: :eu
  defp to_jurisdiction("us"), do: :us
  defp to_jurisdiction("ch"), do: :ch
  defp to_jurisdiction(_), do: :unknown

  defp strip_fences(raw) do
    raw
    |> String.trim()
    |> String.replace(~r/\A```(?:json)?\s*/, "")
    |> String.replace(~r/\s*```\z/, "")
    |> String.trim()
  end

  defp elapsed_us(started_at) do
    System.convert_time_unit(System.monotonic_time() - started_at, :native, :microsecond)
  end
end
