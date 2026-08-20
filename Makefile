# Diagnostics use an existing ChatGPT-plan login through Codex, then the fixed
# local Ollama fallback in config/config.exs.

.PHONY: setup deps compile test test-property test-e2e test-stress test-llm \
        check quality clean install-hooks iex remote \
        bench-eval bench-partition bench-verifier \
        health server scenario storm ai benchmark diagnostics-demo diagnostics-down \
        swarm-up swarm-down swarm-scale slides slides-clean rehearse-solo

setup:
	@mix setup
	@echo "==> Now install the interpreter: mix maude.install"

# Independent checks for Maude, transport, fleet, engine, Codex, and Ollama.
# Non-zero if Maude or both diagnostic providers are unavailable.
health:
	@mix goatmire.health

server:
	@mix phx.server

# `.iex.exs` aliases the console helpers as GM.
iex:
	@iex -S mix

# Attach to an already running production release node.
remote:
	@_build/prod/rel/goatmire/bin/goatmire remote

# Run a scenario:
#   make scenario N=1
#   make scenario N=2 MODE=observe FLEET=60 DURATION=30
scenario:
	@mix goatmire.scenario $(N) \
		$(if $(FLEET),--fleet $(FLEET),) \
		$(if $(DURATION),--duration $(DURATION),) \
		$(if $(MODE),--mode $(MODE),)

# The storm on its own:
#   make storm                 # enforce
#   make storm COMPARE=1       # both halves + ratio
storm:
	@mix goatmire.storm \
		$(if $(FLEET),--fleet $(FLEET),--fleet 200) \
		$(if $(DURATION),--duration $(DURATION),--duration 60) \
		$(if $(COMPARE),--compare,)

# Generated rules through the configured model.
ai:
	@mix goatmire.ai $(PROMPT)

benchmark:
	@mix goatmire.benchmark $(if $(RUNS),--runs $(RUNS),) $(if $(OUTPUT),--output $(OUTPUT),)

# Host engine + local Codex/Ollama; containers provide only the broker,
# simulators, and raw metrics tools. No Codex credential directory is mounted.
diagnostics-demo:
	@docker compose -f docker/docker-compose.diagnostics.yml up --build -d --scale simulator=$(or $(N),2)
	@mix goatmire.health
	@mix phx.server

diagnostics-down:
	@docker compose -f docker/docker-compose.diagnostics.yml down

swarm-up:
	@docker compose -f docker/docker-compose.yml up --build -d --scale simulator=2

# make swarm-scale N=8
swarm-scale:
	@docker compose -f docker/docker-compose.yml up -d --scale simulator=$(or $(N),4)

swarm-down:
	@docker compose -f docker/docker-compose.yml down -v

slides:
	@cd docs/talk/slides && npm ci && npm run build

slides-clean:
	@cd docs/talk/slides && npm run clean

stage:
	@test -f docs/talk/slides/dist/goatmire-2026.html || (echo "run 'make slides' first" && exit 1)
	@open -na "Google Chrome" --args --new-window \
		"file://$(PWD)/docs/talk/slides/dist/goatmire-2026.html" \
		"http://localhost:4000/rules/new" \
		"http://localhost:4000/warehouse" \
		"http://localhost:4000/diagnostics" \
		"http://localhost:4000/verify" \
		"http://localhost:3001"

stage-tmux:
	@command -v tmuxp >/dev/null || (echo "install tmuxp: brew install tmuxp" && exit 1)
	@tmuxp load priv/tmux/goatmire.tmuxp.yaml

rehearse-solo:
	@echo "==> Phase 1 solo rehearsal — read docs/talk/script.md aloud against a stopwatch."
	@open docs/talk/script.md || xdg-open docs/talk/script.md || cat docs/talk/script.md

deps:
	@mix deps.get

compile:
	@mix compile --warnings-as-errors

test:
	@mix test

test-property:
	@mix test.property

# Install a matching driver into tmp/tools first.
test-e2e:
	@scripts/install-chromedriver.sh
	@mix test.e2e

# Deliberately manual: heavier concurrency and a real loopback Ollama model.
test-stress:
	@mix test.stress

test-llm:
	@mix test.llm

bench-eval:
	@mix run --no-start bench/rule_eval_bench.exs

bench-partition:
	@mix run --no-start bench/partition_bench.exs

bench-verifier:
	@mix run --no-start bench/verifier_bench.exs

check:
	@mix check

quality:
	@mix quality

install-hooks:
	@./scripts/install-hooks.sh

clean:
	@mix clean
	@rm -rf _build deps priv/static/assets
