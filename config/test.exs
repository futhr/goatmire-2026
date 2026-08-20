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
  metrics_enabled: false

config :goatmire, GoatmireWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 0],
  secret_key_base: String.duplicate("goatmire-test-secret", 4),
  check_origin: false,
  server: true

config :wallaby,
  driver: Wallaby.Chrome,
  screenshot_dir: "tmp/wallaby",
  max_wait_time: 8_000,
  screenshot_on_failure: true,
  js_errors: true,
  js_logger: nil,
  chromedriver: [
    path: Path.expand("../tmp/tools/chromedriver", __DIR__),
    headless: true
  ]

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
