import Config

config :goatmire,
  transport: Goatmire.Transport.MQTT,
  vda5050_enabled: false

config :goatmire, GoatmireWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: true,
  code_reloader: true,
  debug_errors: true,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/goatmire_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, level: :info
