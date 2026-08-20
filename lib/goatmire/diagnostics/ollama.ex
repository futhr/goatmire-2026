defmodule Goatmire.Diagnostics.Ollama do
  @moduledoc """
  The local fallback reasoner: one non-streaming completion against the
  pinned Ollama model over the OpenAI-compatible API.

  Reasoning effort is off and output tokens are capped — a stage answer that
  arrives late is an answer that did not arrive. `preflight/0` checks that
  the exact configured model is served, not merely that Ollama is up.

  Swappable via `config :goatmire, diagnostics_ollama_runner: MyModule` so
  tests never need a live server.
  """

  alias Goatmire.Config

  @doc "Completes one diagnostic prompt with the configured local Ollama model."
  @spec complete([map()], keyword()) :: {:ok, String.t(), map()} | {:error, term()}
  def complete(messages, opts \\ []) do
    model = Config.diagnostics_ollama_model()
    timeout = Keyword.get(opts, :timeout, Config.diagnostics_ollama_timeout_ms())
    max_tokens = Keyword.get(opts, :max_tokens, Config.diagnostics_ollama_max_tokens())

    body =
      %{
        model: model,
        messages: messages,
        stream: false,
        reasoning_effort: "none",
        max_tokens: max_tokens
      }
      |> maybe_put(:response_format, Keyword.get(opts, :response_format))

    response =
      :telemetry.span(
        [:goatmire, :diagnostics, :http],
        %{provider: :ollama, operation: :complete},
        fn ->
          result =
            Req.post(
              Config.diagnostics_ollama_base_url() <> "/chat/completions",
              req_options(json: body, receive_timeout: timeout)
            )

          {result, response_metadata(result)}
        end
      )

    case response do
      {:ok, %{status: 200, body: response}} ->
        case get_in(response, ["choices", Access.at(0), "message", "content"]) do
          content when is_binary(content) and content != "" ->
            {:ok, content, %{provider: :ollama, model: model}}

          _ ->
            {:error, :invalid_ollama_response}
        end

      {:ok, %{status: status}} ->
        {:error, {:ollama_http_status, status}}

      {:error, reason} ->
        {:error, {:ollama_unavailable, inspect(reason, limit: 5, printable_limit: 300)}}
    end
  end

  @doc "Checks that Ollama serves the exact configured fallback model."
  @spec preflight() :: {:ok, map()} | {:error, term()}
  def preflight do
    response =
      :telemetry.span(
        [:goatmire, :diagnostics, :http],
        %{provider: :ollama, operation: :preflight},
        fn ->
          result =
            Req.get(
              Config.diagnostics_ollama_base_url() <> "/models",
              req_options(receive_timeout: 2_000)
            )

          {result, response_metadata(result)}
        end
      )

    case response do
      {:ok, %{status: 200, body: %{"data" => models}}} when is_list(models) ->
        configured = Config.diagnostics_ollama_model()
        available = Enum.any?(models, &(&1["id"] == configured))

        if available,
          do: {:ok, %{model: configured}},
          else: {:error, {:ollama_model_missing, configured}}

      {:ok, %{status: status}} ->
        {:error, {:ollama_http_status, status}}

      {:error, reason} ->
        {:error, {:ollama_unavailable, inspect(reason, limit: 5, printable_limit: 300)}}
    end
  end

  defp maybe_put(map, _, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp response_metadata({:ok, %{status: status}}), do: %{status: status}
  defp response_metadata({:error, _}), do: %{status: :transport_error}

  defp req_options(options) do
    Keyword.merge(
      [retry: false],
      Keyword.merge(options, Application.get_env(:goatmire, :diagnostics_req_options, []))
    )
  end
end
