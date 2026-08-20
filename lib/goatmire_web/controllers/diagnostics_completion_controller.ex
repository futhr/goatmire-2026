defmodule GoatmireWeb.DiagnosticsCompletionController do
  @moduledoc """
  Loopback-only OpenAI-compatible completions endpoint.

  BeamLens's client registry points here
  (`Goatmire.Config.diagnostics_bridge_url/0`),
  so the coordinator treats Codex-or-Ollama selection as one provider.
  Refuses non-loopback callers and streaming.
  """

  use GoatmireWeb, :controller

  alias Goatmire.Diagnostics.Provider

  @doc "Handles loopback-only, non-streaming diagnostic completion requests."
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"messages" => messages} = params) when is_list(messages) do
    if loopback?(conn.remote_ip) and params["stream"] != true do
      opts =
        []
        |> maybe_put(:output_schema, output_schema(params["response_format"]))
        |> maybe_put(:response_format, params["response_format"])

      case Provider.complete(messages, opts) do
        {:ok, content, metadata} ->
          json(conn, %{
            id: "goatmire-#{System.unique_integer([:positive])}",
            object: "chat.completion",
            created: System.system_time(:second),
            model: metadata.model,
            choices: [
              %{
                index: 0,
                finish_reason: "stop",
                message: %{role: "assistant", content: content}
              }
            ]
          })

        {:error, :diagnostics_unavailable} ->
          conn
          |> put_status(:service_unavailable)
          |> json(%{error: %{message: "Codex and Ollama diagnostics are unavailable"}})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: %{message: "diagnostic completion bridge is loopback-only"}})
    end
  end

  def create(conn, _) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{message: "expected a non-streaming messages array"}})
  end

  defp loopback?({127, _, _, _}), do: true
  defp loopback?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp loopback?(_), do: false

  defp output_schema(%{"type" => "json_schema", "json_schema" => %{"schema" => schema}}),
    do: schema

  defp output_schema(_), do: nil

  defp maybe_put(opts, _, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
