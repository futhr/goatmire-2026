#!/usr/bin/env bash
# CI builds the two :check images before this real-broker boot check.
set -euo pipefail
network="goatmire-smoke-$$"
broker="${network}-broker"
engine="${network}-engine"
simulator="${network}-simulator"
cleanup() {
  docker rm -f "$engine" "$simulator" "$broker" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker network create "$network" >/dev/null
docker run -d --name "$broker" --network "$network" --network-alias broker \
  -v "$PWD/docker/mosquitto.conf:/mosquitto/config/mosquitto.conf:ro" \
  eclipse-mosquitto:2.1.2-alpine >/dev/null
for _ in $(seq 1 20); do
  if docker exec "$broker" mosquitto_pub -t smoke -m ready; then break; fi
  sleep 1
done
docker run -d --platform linux/amd64 --name "$engine" --network "$network" goatmire-engine:check >/dev/null
docker run -d --platform linux/amd64 --name "$simulator" --network "$network" goatmire-simulator:check >/dev/null
for _ in $(seq 1 40); do
  if docker exec "$engine" curl -fsS http://127.0.0.1:4000/api/health > /dev/null 2>&1; then
    if docker exec "$engine" /app/bin/goatmire rpc \
      'true = Goatmire.Engine.status().things_seen > 0; {:ok, %{status: :conflicts}, _} = Goatmire.Gate.verify_partitioned(Goatmire.Rules.research_state_conflict_pair())' >/dev/null 2>&1; then
      echo "Engine, simulator, broker delivery, and Maude verification passed."
      exit 0
    fi
  fi
  sleep 1
done
docker logs --tail 25 "$engine"
docker logs --tail 25 "$simulator"
exit 1
