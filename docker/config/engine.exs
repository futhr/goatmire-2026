import Config

config :goatmire,
  role: :engine,
  transport: Goatmire.Transport.MQTT,
  mqtt: [
    host: "broker",
    port: 1883,
    client_id: "goatmire-engine",
    username: nil,
    password: nil
  ],
  autostart_fleet: false,
  vda5050_enabled: true,
  metrics_port: 9568,
  llm_base_url: "http://host.docker.internal:11434/v1",
  llm_model: "qwen3.5:4b-q4_K_M",
  diagnostics_ollama_base_url: "http://host.docker.internal:11434/v1"

config :goatmire, GoatmireWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base: String.duplicate("goatmire-local-docker-demo", 3),
  check_origin: false,
  server: true
