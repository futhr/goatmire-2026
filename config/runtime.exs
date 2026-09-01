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
