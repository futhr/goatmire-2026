# Container Support Stack

The stage application runs Phoenix, ExMaude, BeamLens, Codex, and Ollama on the host. Containers supply the broker, simulated fleet, Prometheus, and Grafana:

```bash
docker compose -f docker/docker-compose.diagnostics.yml up -d --scale simulator=2
```

Or use `make diagnostics-demo`, which starts the support services, runs the health check, and launches the host application.

| Service | Port | Stage role |
|---|---:|---|
| `broker` | 1883 | MQTT serialization boundary |
| `simulator` | — | fully simulated fleet; scalable replicas |
| `prometheus` | 9090 | raw metric store and query fallback |
| `grafana` | 3001 | supporting raw dashboard |

The host metrics endpoint is reached from the Prometheus container through `host.docker.internal`. No Codex credential or home directory is mounted into a container. Every published container port is bound to host loopback; the support services are not exposed on the laptop's LAN interfaces.

Useful views:

- primary diagnostic UI: <http://localhost:4000/diagnostics>
- Prometheus: <http://localhost:9090>
- Grafana: <http://localhost:3001>

BeamLens is the rehearsed diagnostic surface because it answers a question from a bounded structured snapshot. Prometheus and Grafana let the operator inspect the raw series that ground the response.

## Scaling the simulator

```bash
docker compose -f docker/docker-compose.diagnostics.yml up -d --scale simulator=8
```

Simulator replicas derive disjoint `thing_id` offsets from their hostnames. Edit `docker/config/simulator.exs` if a rehearsal needs a different fleet size. Scaling adds real broker and network pressure, but it remains simulation and does not establish a datacenter or physical-fleet benchmark.

## Extended compose file

`docker/docker-compose.yml` is retained for the older all-container/Livebook workflow. It is not the stage topology because containerizing the engine would require credential plumbing for Codex and complicate the local Ollama bridge. The full file now reaches the fixed Ollama fallback through `host.docker.internal`, but it still cannot consume the host's Codex login. Use `docker-compose.diagnostics.yml` for the approved talk path.

## Licensing and boundaries

The Maude interpreter is GPL and is not bundled by the ExMaude Hex package. The legacy engine image installs it at build time; publishing that image must respect its license.

This is not a production topology. The broker is anonymous and unencrypted, Grafana has no login, the engine keeps state in memory, and all stage devices are simulated.
