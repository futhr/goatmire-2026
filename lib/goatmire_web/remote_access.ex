defmodule GoatmireWeb.RemoteAccess do
  @moduledoc "Checks stage sessions at HTTP entry and on connected LiveView events."
  import Plug.Conn, only: [get_session: 1, send_resp: 3, halt: 1]
  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  @doc "Current stage credential; rotating the token invalidates existing sessions."
  @spec credential() :: String.t() | nil
  def credential do
    case Goatmire.Config.talk_remote_token() do
      token when is_binary(token) and byte_size(token) >= 12 ->
        Base.encode64(:crypto.hash(:sha256, token))

      _ ->
        nil
    end
  end

  @doc "Checks the session against the current stage token."
  @spec authorized?(map()) :: boolean()
  def authorized?(session) do
    expected = credential()
    supplied = session["talk_credential"] || session[:talk_credential]
    is_binary(expected) and is_binary(supplied) and Plug.Crypto.secure_compare(expected, supplied)
  end

  @doc false
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @doc "Keeps unauthenticated remote callers on the notes unlock surface."
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _) do
    if loopback?(conn.remote_ip) or public_path?(conn.request_path) or
         authorized?(get_session(conn)) do
      conn
    else
      conn
      |> send_resp(403, "Unlock the stage session at /talk/notes first.")
      |> halt()
    end
  end

  @doc "Checks connected clients and revalidates their credential before every event."
  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _, session, socket) do
    peer = if is_nil(socket.parent_pid), do: get_connect_info(socket, :peer_data)
    local = local_peer?(peer) or session["stage_loopback"] == true

    notes = socket.view == GoatmireWeb.SpeakerNotesLive

    if local or notes or authorized?(session) do
      socket =
        attach_hook(socket, :stage_access, :handle_event, fn _, _, current ->
          authorize_event(current, session, notes, local)
        end)

      forwarded = Map.put(session, "stage_loopback", local)
      {:cont, assign(socket, :stage_session, forwarded)}
    else
      {:halt, redirect(socket, to: "/talk/notes")}
    end
  end

  defp local_peer?(%{address: address}), do: loopback?(address)
  defp local_peer?(_), do: false

  defp authorize_event(socket, session, notes, local) do
    cond do
      notes and not authorized?(session) -> {:halt, assign(socket, :authorized?, false)}
      local or authorized?(session) -> {:cont, socket}
      true -> {:halt, redirect(socket, to: "/talk/notes")}
    end
  end

  defp public_path?(path),
    do:
      String.starts_with?(path, "/talk/notes") or path == "/api/health" or
        String.starts_with?(path, "/api/internal/diagnostics/")

  defp loopback?({127, _, _, _}), do: true
  defp loopback?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp loopback?(_), do: false
end
