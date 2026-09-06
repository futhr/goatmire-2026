import Config

config :goatmire, GoatmireWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: true,
  server: true

config :logger, level: :info
