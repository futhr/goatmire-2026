defmodule GoatmireWeb.Presenter.PairingCode do
  @moduledoc """
  The projected QR code that opens the speaker notes on a tablet.

  The link names the configured stage host, the only origin the endpoint
  accepts LiveView sockets from in remote mode. Its code is single-use and
  short-lived; see `Goatmire.Talk.Pairing`.
  """

  alias Goatmire.Config
  alias Goatmire.Talk.Pairing
  alias GoatmireWeb.Presenter.QRCode

  @type t :: %{qr: String.t(), host: String.t(), url: String.t()}

  @doc "Issues a code and returns the QR image with the address it points at."
  @spec start() :: {:ok, t()} | {:error, :remote_disabled}
  def start do
    with host when is_binary(host) <- Config.talk_host(),
         {:ok, code} <- Pairing.issue() do
      host = "#{host}:#{GoatmireWeb.Endpoint.config(:http)[:port]}"
      url = "http://#{host}/talk/notes/pair/#{code}"
      {:ok, %{qr: QRCode.data_uri(url), host: host, url: url}}
    else
      _ -> {:error, :remote_disabled}
    end
  end
end
