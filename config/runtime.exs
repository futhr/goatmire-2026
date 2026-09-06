import Config

talk_remote? = System.get_env("GOATMIRE_TALK_REMOTE") in ["1", "true"]
talk_remote_token = System.get_env("GOATMIRE_TALK_REMOTE_TOKEN")

if talk_remote? do
  if is_nil(talk_remote_token) or byte_size(talk_remote_token) < 12 do
    raise "GOATMIRE_TALK_REMOTE_TOKEN must contain at least 12 characters"
  end

  config :goatmire,
    talk_remote_token: talk_remote_token

  config :goatmire, GoatmireWeb.Endpoint, http: [ip: {0, 0, 0, 0}, port: 4000]
end

profile = "/app/goatmire.runtime.exs"

if File.regular?(profile) do
  for {application, values} <- Config.Reader.read!(profile) do
    config application, values
  end
end

# A fresh signing key invalidates cookies on restart. A deliberate external
# key can be supplied for deployments that need session continuity.
config :goatmire, GoatmireWeb.Endpoint,
  secret_key_base:
    System.get_env("GOATMIRE_SECRET_KEY_BASE") || Base.encode64(:crypto.strong_rand_bytes(64))

if talk_remote? do
  stage_host = System.fetch_env!("GOATMIRE_TALK_HOST")

  config :goatmire, GoatmireWeb.Endpoint,
    check_origin: ["//localhost", "//127.0.0.1", "//" <> stage_host]
end
