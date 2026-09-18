defmodule GoatmireWeb.SpeakerNotesController do
  @moduledoc false

  use GoatmireWeb, :controller

  alias Goatmire.Config
  alias Goatmire.Talk.Pairing

  @doc "Unlocks the private speaker-notes session when the stage token matches."
  @spec unlock(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unlock(conn, %{"token" => provided}) do
    if valid_token?(provided), do: authorize(conn), else: not_found(conn, "Not found")
  end

  @doc "Unlocks the speaker-notes session with a one-time code from the presenter QR."
  @spec pair(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def pair(conn, %{"code" => code}) do
    case Pairing.redeem(code) do
      :ok -> authorize(conn)
      :error -> not_found(conn, "This code expired or was already used. Press q for a new one.")
    end
  end

  defp authorize(conn) do
    conn
    |> configure_session(renew: true)
    |> put_session(:talk_credential, GoatmireWeb.RemoteAccess.credential())
    |> redirect(to: ~p"/talk/notes")
  end

  # With `nosniff` and no content type, iPad Safari offers a 404 as a download.
  defp not_found(conn, message) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, message)
  end

  defp valid_token?(provided) when is_binary(provided) do
    case Config.talk_remote_token() do
      expected when is_binary(expected) and byte_size(expected) >= 12 ->
        byte_size(provided) == byte_size(expected) and
          Plug.Crypto.secure_compare(provided, expected)

      _ ->
        false
    end
  end
end
