# Container support stack

The stage application runs Phoenix, ExMaude, BeamLens, Codex, and Ollama on the host. Containers supply the broker and simulated fleet:

```bash
docker compose -f docker/docker-compose.diagnostics.yml up -d --scale simulator=2
```

`make diagnostics-demo` builds and starts those support services. Start exactly one host application with `make talk-stage` (LAN notes) or `make server` (loopback). Run `make health` from another terminal; it probes the running application.

| Service | Port | Role |
|---|---:|---|
| `broker` | 1883 | MQTT serialization boundary |
| `simulator` | — | fully simulated fleet; scalable replicas |
| `livebook` (optional) | 8080 | independent teaching runtime; start with `make notebooks` |

The optional Livebook image includes Maude 3.5.1 and mounts the clone at `/data/goatmire`. Open notebooks from that directory. Setup compiles the pinned project in its own runtime; it does not attach to the stage node. The stage uses the embedded `/talk` notebook pane. No Codex credential or home directory is mounted into any container. Every published container port is bound to host loopback; the support services are not exposed on the laptop's LAN interfaces.

The host's Prometheus exporter stays on `:9568` — it is what makes the simulators observable — but no Prometheus or Grafana container runs; the in-app Metrics pane carries the raw series.

## Scaling the simulator

```bash
make simulators N=8
```

Simulator replicas derive disjoint `thing_id` offsets from their hostnames. Edit `docker/config/simulator.exs` if a rehearsal needs a different fleet size. Scaling adds real broker and network pressure, but it remains simulation and does not establish a datacenter or physical-fleet benchmark.

## Licensing and boundaries

The Maude interpreter is GPL and is not bundled by the ExMaude Hex package; the host installs it with `mix maude.install --version 3.5.1`. The engine and optional Livebook images download it at build time and include its GPL obligations.

This is not a production topology. The broker is anonymous and unencrypted, Livebook runs without a token, the engine keeps state in memory, and all stage devices are simulated.
