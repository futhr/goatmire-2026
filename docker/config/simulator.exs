import Config

{:ok, hostname} = :inet.gethostname()
hostname = List.to_string(hostname)
fleet_size = 100

config :goatmire,
  role: :simulator,
  transport: Goatmire.Transport.MQTT,
  mqtt: [
    host: "broker",
    port: 1883,
    client_id: "goatmire-#{hostname}",
    username: nil,
    password: nil
  ],
  autostart_fleet: true,
  fleet_size: fleet_size,
  fleet_offset: rem(:erlang.phash2(hostname), 100_000) * fleet_size,
  device_tick_ms: 1_000,
  vda5050_enabled: true,
  metrics_port: 9568
