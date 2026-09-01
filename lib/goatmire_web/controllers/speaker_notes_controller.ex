defmodule GoatmireWeb.SpeakerNotesController do
  @moduledoc false

  use GoatmireWeb, :controller

  alias Goatmire.Config

  def unlock(conn, %{"token" => provided}) do
    if valid_token?(provided) do
      conn
      |> configure_session(renew: true)
      |> put_session(:talk_notes_authorized, true)
      |> redirect(to: ~p"/talk/notes")
    else
      send_resp(conn, 404, "Not found")
    end
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
