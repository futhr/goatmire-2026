# Demo Setup — Goatmire 2026

This is the only stage setup. The fleet and all events are simulated; no Pi, sensor, LED strip, or other physical device is required or shown as evidence.

## Architecture

```text
browser
  ├─ /warehouse      simulated events + observe/enforce comparison
  ├─ /rules          deployment request + Maude verdict
  └─ /diagnostics    BeamLens prompt + grounded explanation
          │
host Phoenix/BEAM ───┼─ ExMaude/Maude (the formal decision)
          │           ├─ Codex app-server (ChatGPT-plan explanation)
          │           └─ Ollama (fixed local fallback explanation)
          │
containers ──────────┴─ MQTT + simulators + Livebook
```

The model is not in the actuation path. BeamLens can call only three read-only diagnostic callbacks over a bounded telemetry snapshot. It cannot deploy rules, operate devices, change the Maude verdict, or widen its scope.

## Prerequisites

- the repository's Erlang, Elixir, and Node versions (`mise install`)
- Docker with Compose
- the Maude interpreter (`mix maude.install`)
- one diagnostic explanation provider:
  - preferred: installed Codex CLI already signed in with a ChatGPT plan; or
  - fallback: Ollama with `qwen3.5:4b-q4_K_M`

No OpenAI API key is used. Codex consumes included ChatGPT-plan usage and the bridge refuses API-key accounts. Ollama keeps diagnostic prompts and metric snapshots local.

## First setup

```bash
mise install
mix setup
mix maude.install

# Install this before travel so it is already on disk.
ollama pull qwen3.5:4b-q4_K_M
```

If Codex is the intended primary provider, confirm the CLI is signed into the same ChatGPT-plan account that will be used on stage. Never copy its credential files into the repository or a container.

## Start the complete rig

Start Ollama in its own terminal, even when Codex is expected to work:

```bash
ollama serve
```

Then start the support stack and host application:

```bash
make diagnostics-demo
```

That command starts MQTT, simulator containers, and Livebook, runs the application health check, and then starts Phoenix/ExMaude/BeamLens on the host. The host arrangement lets Codex use the existing desktop login without mounting credentials.

Useful URLs:

| Surface | URL | Stage role |
|---|---|---|
| Presenter | <http://localhost:4000/talk> | the stage surface — deck, panes, timer |
| Livebook | <http://localhost:8080> | LIVE 04, the teaching notebooks, and the lab |
| Warehouse | <http://localhost:4000/warehouse> | simulated load and counters |
| Rule editor | <http://localhost:4000/rules> | formal gate |
| Diagnostics | <http://localhost:4000/diagnostics> | primary operational explanation |
| BeamLens inspector | <http://localhost:4000/beamlens> | advanced fallback/inspection |



## Preflight

Run this after boot and again immediately before the talk:

```bash
mix goatmire.health
mix test --include maude
mix goatmire.benchmark --runs 5 --output tmp/goatmire-benchmark.json
make preflight               # full gate: compile, suite, chaos + starvation, health
```

The health task must report:

1. Maude is available.
2. The engine and simulated fleet are reachable.
3. Codex is a ChatGPT account with usable included quota, or it is visibly unavailable for a stated reason.
4. Ollama has the fixed fallback model, or it is visibly unavailable.
5. At least one diagnostic provider is ready.

Open `/diagnostics` and verify the provider badge before sending a prompt. There is deliberately no diagnostic model request during page load.

## Rehearsed demo path

1. In `/rules`, seed the reproduced O3 `switch=on` rule, load O4 as the candidate, and press **Check and create**. Both receive `contact=open`, but O4 writes `switch=off`.
2. Read the red verdict, rule IDs, witness, partitions, pairs considered, and pairs skipped. Say that the rule shape is reproduced from research—not a real incident and not proof that Maude would have prevented every outcome.
3. In `/warehouse`, run the staged synthetic shift change in **observe** mode. The verifier records conflicts while the conflicting rules still deploy.
4. Reset and run the same staged load in **enforce** mode. Conflicting rules are withheld; read this run's counters instead of quoting rehearsal data.
5. Open `/diagnostics` and ask:

> Why did alerts rise in the last minute, what formal verdict accompanies > the run, and what should I inspect next?

6. Point out the cited metric fields, observations versus inference, confidence/grounding, and provider badge. Say: “Maude made the deterministic conflict decision; the model explained the bounded telemetry snapshot.”
7. If challenged, corroborate one raw series on the Metrics pane.

The stage-facing path sends one schema-constrained provider completion over the Goatmire BeamLens skill's already-bounded snapshot, with one 30-second task timeout. Exact evidence lines come from the snapshot, not model prose. The iterative BeamLens coordinator remains available in the inspector with a six-turn cap; its history window is limited to five minutes.

## Failure matrix

| Failure | Visible behavior | Stage response |
|---|---|---|
| Codex signed out | provider badge explains auth failure; Ollama selected | continue locally |
| Codex API-key account | bridge refuses it; Ollama selected | state that pay-per-token auth is disabled |
| ChatGPT plan quota exhausted | quota reason shown; Ollama selected | continue locally |
| Conference network absent | Codex may fail; Ollama selected | continue locally |
| Ollama absent but Codex ready | Codex selected | continue; local fallback unavailable |
| Both model providers absent | deterministic evidence answer; badge says unavailable | read exact fields on the Metrics pane and omit model inference |
| Maude timeout/crash | verdict is `unverified`; enforce deploys nothing | make fail-closed behavior the demo |
| MQTT/support stack fails | use local transport and host-simulated fleet | skip container scale claim |


Never present a generated explanation as a proof. If the explanation conflicts with the displayed verdict or cited fields, trust the structured telemetry and Maude result and say the explanation is wrong.

## Day-of checklist

- [ ] Restart the MQTT broker before the stage boot (`docker restart` the broker container). Big rehearsal fleets leave retained VDA 5050 topics behind, and a fresh engine replays every ghost device at connect; the broker runs with `persistence false`, so one restart clears them.
- [ ] Disable sleep, notifications, automatic updates, and VPN surprises.
- [ ] Use a clean browser profile at 125–150% zoom.
- [ ] Confirm the projector can read verdict, witness, stats, and provider badge.
- [ ] Confirm Maude, Codex account/quota state, and the Ollama model with `mix goatmire.health`.
- [ ] Run one observe/enforce pair with the final fleet size.
- [ ] Ask one BeamLens prompt and confirm the answer cites snapshot fields.
- [ ] Open Scenario 5 in the Livebook container once so its project cache is warm.
- [ ] Store the final benchmark artifact with the rehearsal notes.
- [ ] Rehearse both-model-failure and Maude-`unverified` fallbacks aloud.
- [ ] If any live number differs from rehearsal, read the live result and discard the prepared number.

## Stop the rig

```bash
make diagnostics-down
```

The diagnostics topology defines no persistent volumes; stopping it loses nothing that matters. No stage hardware or hardware packing procedure exists for this version of the talk.
