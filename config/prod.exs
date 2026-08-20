import Config

config :goatmire, GoatmireWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: String.duplicate("goatmire-local-demo-release", 3),
  check_origin: false,
  server: true

config :logger, level: :info
