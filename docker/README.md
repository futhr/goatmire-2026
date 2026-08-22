# Container support stack

The stage application runs Phoenix, ExMaude, BeamLens, Codex, and Ollama on the host. Containers supply the broker, the simulated fleet, and Livebook:

```bash
docker compose -f docker/docker-compose.diagnostics.yml up -d --scale simulator=2
```

Or use `make diagnostics-demo`, which starts the support services, runs the health check, and launches the host application.

| Service | Port | Role |
|---|---:|---|
| `broker` | 1883 | MQTT serialization boundary |
| `simulator` | — | fully simulated fleet; scalable replicas |
| `livebook` | 8080 | LIVE 04 on stage; the teaching notebooks and scenario lab off stage |

The repo is mounted read-only into the Livebook container so the notebooks' `Mix.install` path resolves; the first notebook run fetches and compiles into the container's cache, so warm it during rehearsal. No Codex credential or home directory is mounted into any container. Every published container port is bound to host loopback; the support services are not exposed on the laptop's LAN interfaces.

The host's Prometheus exporter stays on `:9568` — it is what makes the simulators observable — but no Prometheus or Grafana container runs; the in-app Metrics pane carries the raw series.

## Scaling the simulator

```bash
make simulators N=8
```

Simulator replicas derive disjoint `thing_id` offsets from their hostnames. Edit `docker/config/simulator.exs` if a rehearsal needs a different fleet size. Scaling adds real broker and network pressure, but it remains simulation and does not establish a datacenter or physical-fleet benchmark.

## Licensing and boundaries

The Maude interpreter is GPL and is not bundled by the ExMaude Hex package; the host installs it with `mix maude.install`.

This is not a production topology. The broker is anonymous and unencrypted, Livebook runs without a token, the engine keeps state in memory, and all stage devices are simulated.
