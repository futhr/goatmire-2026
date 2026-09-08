import Config

config :goatmire,
  transport: Goatmire.Transport.Local,
  autostart_fleet: false,
  fleet_size: 4,
  device_tick_ms: 0,
  llm_base_url: "http://localhost:1/v1",
  llm_model: "test-model",
  llm_test_base_url: "http://127.0.0.1:11434/v1",
  llm_test_model: "qwen3.5:4b-q4_K_M",
  metrics_enabled: false,
  talk_state_path: nil,
  talk_remote_token: "test-speaker-notes"

config :goatmire, GoatmireWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 0],
  secret_key_base: String.duplicate("goatmire-test-secret", 4),
  check_origin: false,
  server: true

config :phoenix_test, otp_app: :goatmire

config :phoenix_test,
  playwright: [
    assets_dir: Path.expand("../assets", __DIR__),
    browser_pool: :chromium,
    browser_pools: [[id: :chromium, browser: :chromium, size: 1]],
    timeout: 8_000
  ]

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
