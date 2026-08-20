defmodule GoatmireWeb.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :goatmire

  @session_options [
    store: :cookie,
    key: "_goatmire_key",
    signing_salt: "5Pkq2rTz",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false

  plug Plug.Static,
    at: "/",
    from: :goatmire,
    gzip: false,
    only: GoatmireWeb.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug GoatmireWeb.Router
end
