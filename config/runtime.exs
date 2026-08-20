import Config

profile = "/app/goatmire.runtime.exs"

if File.regular?(profile) do
  for {application, values} <- Config.Reader.read!(profile) do
    config application, values
  end
end
