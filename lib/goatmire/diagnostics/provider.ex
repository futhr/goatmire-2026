defmodule Goatmire.Diagnostics.Provider do
  @moduledoc """
  Chooses the no-extra-billing diagnostic reasoner.

  Codex authenticated through the user's ChatGPT plan is primary. Any missing
  login, API-key auth, exhausted quota, timeout, or app-server failure falls
  back to the fixed local Ollama model. Provider selection is broadcast so a
  stage audience never sees a silent switch.
  """

  alias Goatmire.Config
  @topic "goatmire:diagnostics"
  @status_key {__MODULE__, :status}

  @doc "PubSub topic carrying diagnostic-provider state changes."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc "Last published provider state, or an idle state before the first request."
  @spec status() :: map()
  def status do
    :persistent_term.get(@status_key, %{
      state: :idle,
      provider: nil,
      model: nil,
      reason: nil,
      completed_at: nil
    })
  end

  @doc "Completes through Codex plan access, falling back visibly to local Ollama."
  @spec complete([map()], keyword()) :: {:ok, String.t(), map()} | {:error, term()}
  def complete(messages, opts \\ []) do
    started_at = System.monotonic_time(:millisecond)
    publish(%{state: :running, provider: :codex, model: nil, reason: nil})

    codex_opts =
      opts
      |> Keyword.put_new(:timeout, Config.diagnostics_codex_timeout_ms())
      |> Keyword.put_new(:model, Config.diagnostics_codex_model())

    case codex_runner().complete(messages, codex_opts) do
      {:ok, content, metadata} ->
        finish(:ok, content, metadata, nil, started_at)

      {:error, codex_reason} ->
        publish(%{
          state: :fallback,
          provider: :ollama,
          model: Config.diagnostics_ollama_model(),
          reason: reason_label(codex_reason)
        })

        case ollama_runner().complete(messages, opts) do
          {:ok, content, metadata} ->
            finish(:ok, content, metadata, codex_reason, started_at)

          {:error, ollama_reason} ->
            finish(
              :error,
              nil,
              %{provider: nil, model: nil},
              {codex_reason, ollama_reason},
              started_at
            )
        end
    end
  end

  @doc "Checks both reasoners without consuming a model turn."
  @spec preflight() :: %{codex: term(), ollama: term(), available: boolean()}
  def preflight do
    codex = codex_runner().preflight()
    ollama = ollama_runner().preflight()

    %{
      codex: codex,
      ollama: ollama,
      available: match?({:ok, _}, codex) or match?({:ok, _}, ollama)
    }
  end

  @doc "Checks provider availability and publishes a stage-facing status."
  @spec refresh_status() :: %{codex: term(), ollama: term(), available: boolean()}
  def refresh_status do
    availability = preflight()
    publish(availability_status(availability))
    availability
  end

  defp finish(:ok, content, metadata, fallback_reason, started_at) do
    elapsed_ms = System.monotonic_time(:millisecond) - started_at

    status = %{
      state: :ready,
      provider: metadata.provider,
      model: metadata.model,
      reason: if(fallback_reason, do: reason_label(fallback_reason)),
      plan_type: metadata[:plan_type],
      quota: metadata[:quota],
      elapsed_ms: elapsed_ms,
      completed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    publish(status)
    emit(status, :ok)
    {:ok, content, status}
  end

  defp finish(:error, _, _, reason, started_at) do
    elapsed_ms = System.monotonic_time(:millisecond) - started_at

    status = %{
      state: :unavailable,
      provider: nil,
      model: nil,
      reason: reason_label(reason),
      elapsed_ms: elapsed_ms,
      completed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    publish(status)
    emit(status, :error)
    {:error, :diagnostics_unavailable}
  end

  defp emit(status, result) do
    :telemetry.execute(
      [:goatmire, :diagnostics, :completion],
      %{duration_ms: status.elapsed_ms},
      %{
        provider: status.provider,
        model: status.model,
        result: result,
        fallback: status.reason != nil
      }
    )
  end

  defp publish(status) do
    status = Map.put_new(status, :completed_at, nil)
    :persistent_term.put(@status_key, status)

    Phoenix.PubSub.broadcast(Goatmire.PubSub, @topic, {:diagnostics_provider, status})
    :ok
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp availability_status(%{codex: {:ok, metadata}}) do
    %{
      state: :available,
      provider: :codex,
      model: nil,
      reason: nil,
      plan_type: metadata[:plan_type],
      quota: metadata[:quota]
    }
  end

  defp availability_status(%{codex: {:error, codex_reason}, ollama: {:ok, metadata}}) do
    %{
      state: :available,
      provider: :ollama,
      model: metadata[:model] || Config.diagnostics_ollama_model(),
      reason: reason_label(codex_reason)
    }
  end

  defp availability_status(%{codex: {:error, codex_reason}, ollama: {:error, ollama_reason}}) do
    %{
      state: :unavailable,
      provider: nil,
      model: nil,
      reason: reason_label({codex_reason, ollama_reason})
    }
  end

  defp reason_label({codex, ollama}),
    do: "Codex: #{reason_label(codex)}; Ollama: #{reason_label(ollama)}"

  defp reason_label(:api_key_auth_refused),
    do: "API-key auth refused; ChatGPT plan login is required"

  defp reason_label(:chatgpt_login_required), do: "ChatGPT login required"
  defp reason_label(:chatgpt_plan_quota_unavailable), do: "ChatGPT plan quota unavailable"
  defp reason_label(:codex_not_installed), do: "Codex CLI not installed"
  defp reason_label(:codex_timeout), do: "Codex timed out"
  defp reason_label(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_label(reason), do: inspect(reason, limit: 5, printable_limit: 300)

  defp codex_runner do
    Application.get_env(:goatmire, :diagnostics_codex_runner, Goatmire.Diagnostics.CodexRunner)
  end

  defp ollama_runner do
    Application.get_env(:goatmire, :diagnostics_ollama_runner, Goatmire.Diagnostics.Ollama)
  end
end
