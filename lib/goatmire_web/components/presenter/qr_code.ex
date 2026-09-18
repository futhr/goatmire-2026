defmodule GoatmireWeb.Presenter.QRCode do
  @moduledoc """
  QR codes for the stage: the tablet pairing link and the closing slide's
  repositories.

  Error correction level H lets the centre mark cover part of the symbol and
  still scan from the back of a room.
  """

  use Phoenix.Component
  use GoatmireWeb, :verified_routes

  @doc "SVG data URI that encodes `text` at error correction level H."
  @spec data_uri(String.t()) :: String.t()
  def data_uri(text) do
    svg =
      text
      |> EQRCode.encode(:h)
      |> EQRCode.svg(viewbox: true)

    "data:image/svg+xml;base64," <> Base.encode64(svg)
  end

  attr :src, :string, required: true, doc: "a `data_uri/1` result"
  attr :alt, :string, required: true
  attr :class, :any, default: nil

  @doc "A QR code on white, with its quiet zone and the Futhr mark in the centre."
  @spec qr_code(map()) :: Phoenix.LiveView.Rendered.t()
  def qr_code(assigns) do
    ~H"""
    <div class={["qr-code", @class]}>
      <img src={@src} alt={@alt} />
      <img class="qr-code-mark" src={~p"/images/futhr-mark.svg"} alt="" />
    </div>
    """
  end
end
