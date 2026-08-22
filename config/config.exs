import Config

config :goatmire,
  role: :engine,
  transport: Goatmire.Transport.Local,
  mqtt: [
    host: "localhost",
    port: 1883,
    client_id: "goatmire-engine-host",
    username: nil,
    password: nil
  ],
  fleet_size: 200,
  fleet_offset: 0,
  autostart_fleet: false,
  device_tick_ms: 1_000,
  real_devices: [],
  modbus_sensors: [],
  vda5050_enabled: false,
  metrics_port: 9568,
  metrics_enabled: true,
  talk_state_path: "tmp/talk_clock.state",
  llm_base_url: "http://127.0.0.1:11434/v1",
  llm_model: "qwen3.5:4b-q4_K_M",
  llm_timeout_ms: 120_000,
  diagnostics_bridge_url: "http://127.0.0.1:4000/api/internal/diagnostics/v1",
  diagnostics_codex_model: nil,
  diagnostics_codex_timeout_ms: 18_000,
  diagnostics_ollama_base_url: "http://127.0.0.1:11434/v1",
  diagnostics_ollama_model: "qwen3.5:4b-q4_K_M",
  diagnostics_ollama_timeout_ms: 20_000,
  diagnostics_ollama_max_tokens: 320

# The /beamlens inspector wears the same Livebook design tokens as the rest
# of the dashboard (see the extraction notes in the root layout). The fonts
# are the self-hosted files under priv/static/fonts.
config :beamlens_web,
  theme: [
    default: :light,
    light: %{
      "--color-base-100" => "#ffffff",
      "--color-base-200" => "#f0f5f9",
      "--color-base-300" => "#e1e8f0",
      "--color-base-content" => "#304254",
      "--color-primary" => "#3e64ff",
      "--color-primary-content" => "#f5f7ff",
      "--color-secondary" => "#ffa83f",
      "--color-secondary-content" => "#1c2a3a",
      "--color-accent" => "#2d4cdb",
      "--color-accent-content" => "#f5f7ff",
      "--color-neutral" => "#445668",
      "--color-neutral-content" => "#f8fafc",
      "--color-info" => "#6583ff",
      "--color-info-content" => "#f5f7ff",
      "--color-success" => "#4aa148",
      "--color-success-content" => "#ffffff",
      "--color-warning" => "#ffb965",
      "--color-warning-content" => "#1c2a3a",
      "--color-error" => "#e2474d",
      "--color-error-content" => "#ffffff"
    },
    dark: %{
      "--color-base-100" => "#0d1829",
      "--color-base-200" => "#1c2a3a",
      "--color-base-300" => "#304254",
      "--color-base-content" => "#f0f5f9",
      "--color-primary" => "#6583ff",
      "--color-primary-content" => "#0d1829",
      "--color-secondary" => "#ffb965",
      "--color-secondary-content" => "#0d1829",
      "--color-accent" => "#8ba2ff",
      "--color-accent-content" => "#0d1829",
      "--color-neutral" => "#91a4b7",
      "--color-neutral-content" => "#0d1829",
      "--color-info" => "#8ba2ff",
      "--color-info-content" => "#0d1829",
      "--color-success" => "#77b876",
      "--color-success-content" => "#0d1829",
      "--color-warning" => "#ffb965",
      "--color-warning-content" => "#0d1829",
      "--color-error" => "#e97579",
      "--color-error-content" => "#0d1829"
    },
    css: """
    :root { --font-sans: Inter, ui-sans-serif, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; --font-mono: 'JetBrains Mono', 'Droid Sans Mono', monospace; }
    .input:focus, .input:focus-within, .textarea:focus, .textarea:focus-within, .select:focus, .select:focus-within { --input-color: var(--color-primary); border-color: var(--color-primary); outline: 3px solid color-mix(in oklab, var(--color-primary) 15%, transparent); outline-offset: 0; }
    @font-face { font-family: Inter; font-style: normal; font-display: swap; font-weight: 400; src: url(/fonts/inter-latin-400-normal.woff2) format('woff2'); }
    @font-face { font-family: Inter; font-style: normal; font-display: swap; font-weight: 500; src: url(/fonts/inter-latin-500-normal.woff2) format('woff2'); }
    @font-face { font-family: Inter; font-style: normal; font-display: swap; font-weight: 600; src: url(/fonts/inter-latin-600-normal.woff2) format('woff2'); }
    @font-face { font-family: 'JetBrains Mono'; font-style: normal; font-display: swap; font-weight: 400; src: url(/fonts/jetbrains-mono-latin-400-normal.woff2) format('woff2'); }
    """
  ]

config :goatmire, GoatmireWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: GoatmireWeb.ErrorHTML], layout: false],
  pubsub_server: Goatmire.PubSub,
  live_view: [signing_salt: "goatmire2026"]

config :phoenix, :json_library, Jason

config :logger, :console, format: "$time $metadata[$level] $message\n"

import_config "#{config_env()}.exs"
