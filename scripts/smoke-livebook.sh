#!/usr/bin/env bash
# CI builds goatmire-livebook:check before this independent runtime check.
set -euo pipefail
container="goatmire-livebook-smoke-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker run -d --platform linux/amd64 --name "$container" \
  -e LIVEBOOK_TOKEN_ENABLED=false -e LIVEBOOK_GOATMIRE_DIR=/data/goatmire \
  -v "$PWD:/data/goatmire:ro" goatmire-livebook:check >/dev/null
ready=false
for _ in $(seq 1 40); do
  if docker exec "$container" curl -fsS http://127.0.0.1:8080/ >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
if [ "$ready" != true ]; then
  docker logs --tail 30 "$container"
  exit 1
fi
docker exec "$container" curl -fsS --compressed http://127.0.0.1:8080/assets/app.js >/dev/null
docker exec "$container" elixir /data/goatmire/scripts/smoke-notebooks.exs
echo "Livebook HTTP, browser asset, notebook setup, and Maude checks passed."
