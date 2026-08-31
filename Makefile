# Diagnostics use an existing ChatGPT-plan login through Codex, then the fixed
# local Ollama fallback in config/config.exs.

.PHONY: setup deps compile test test-property test-e2e test-stress test-soak test-llm \
        check quality clean install-hooks iex remote \
        bench-eval bench-partition bench-verifier \
        health server scenario storm ai benchmark diagnostics-demo diagnostics-down \
        simulators rehearse-solo talk preflight learn

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

# make simulators N=8 — container simulator replicas over the real broker.
simulators:
	@docker compose -f docker/docker-compose.diagnostics.yml up -d --scale simulator=$(or $(N),2)

rehearse-solo:
	@echo "==> Solo rehearsal — seven beats and anchors first; manuscript only as recovery."
	@open docs/talk/manuscript.md || xdg-open docs/talk/manuscript.md || cat docs/talk/manuscript.md

# The learning cut: seven beats, eighteen anchors, and protected lines.
learn:
	@open docs/talk/memorize.md || xdg-open docs/talk/memorize.md || cat docs/talk/memorize.md

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

# Talk-length wear test; SOAK_ITERATIONS=60 for a longer run.
test-soak:
	@mix test.soak

# The merged presenter is the stage rig: one fullscreen tab, deck left,
# live panel right.
talk:
	@open -na "Google Chrome" --args --new-window --start-fullscreen \
		"http://localhost:4000/talk"

# Talk-day gate: clean compile, the regular suite, then chaos and starvation
# against the real tree, then provider health.
preflight:
	@mix compile --warnings-as-errors
	@mix test
	@mix test.stress
	@mix goatmire.health

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
