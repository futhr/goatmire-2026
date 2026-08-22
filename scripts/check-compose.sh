#!/bin/sh
set -eu

# ExCheck deliberately gives child tools an open stdin pipe. Compose does not
# need input for static validation, and some Docker Desktop releases return 13
# instead of reporting a useful error when that pipe stays open.
exec </dev/null

docker compose -f docker/docker-compose.diagnostics.yml config --quiet
