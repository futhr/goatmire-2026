# Q&A Bank

Answers are intentionally narrower than the most tempting stage claim. When a question exceeds the evidence, name the boundary and follow up rather than inventing certainty.

## Research case and claims

**“Did this actually happen?”** The contact-open pair is a controlled reproduction of a conflict shape reported in SOTERIA's multi-app evaluation: O3 and O4 set a switch to conflicting values for the same event. The demo does not reproduce a harmed household or claim that this code prevented the published result. The warehouse alert storm is synthetic behavior used to compare deployment modes.

**“Why call that a horror story?”** I no longer do. “Published conflict pattern” is more precise. SOTERIA, HOMEGUARD, and IoTCheck show that interaction failures are worth taking seriously; this repository demonstrates one encoded response to that class of problem.

**“Does your model implement SOTERIA or HOMEGUARD?”** No. It reproduces SOTERIA's O3/O4 trigger/action shape in ExMaude's smaller IoT conflict model. HOMEGUARD uses symbolic execution and SMT for its own taxonomy. Those sources motivate the problem; they do not validate this implementation.

**“Could Maude have prevented those events?”** Only conditionally: if the relevant rule semantics had been validated, accurately encoded, checked before activation, covered by the selected predicate, and enforced on the deployment path. That is an architectural counterfactual, not a historical claim.

## Maude and the gate

**“What exactly is proved?”** For the equational detector, a conflict result has a concrete witness in the validated finite term. A clean result means none of the encoded conflict predicates matched that input. It says nothing about physical safety, timing, authorization, sensor validity, or omitted hazards. Bounded reachability with no witness remains `unverified` in this application.

**“Why Maude rather than TLA+, Alloy, or Z3?”** The rule domain maps naturally to algebraic terms and rewrite semantics. TLA+ is often clearer for temporal distributed behavior, Alloy for bounded relations, and SMT/Z3 for constraints. Tool choice should follow property shape and the translation boundary you can validate.

**“Why not property-based testing?”** Use it too. Simulation and generated tests exercise runtime behavior. The equational detector decides a specific predicate over this validated finite term. Neither subsumes the other, and neither supports a property omitted from its model.

**“What if Maude crashes or times out?”** The application returns `unverified`, records telemetry, and enforce mode deploys nothing. Observe mode also fails closed for `unverified`. It deploys `clean` sets normally and — unlike enforce — also deploys a known `conflicts` set, which is what enables the controlled comparison. Pool workers are replaced after uncertain failures.

**“Why have observe mode at all?”** It lets us measure identical synthetic load while recording what the gate would have rejected. It is useful for a rehearsal comparison or carefully controlled shadow deployment. Enforce is the intended gate behavior.

**“Does clean mean safe?”** No. Say “no encoded conflict was found in this input.” A clean verifier that checks four predicates is not a safety case for a physical system.

## Performance and scale

**“How fast is it?”** There is no responsible universal number. The repository benchmark warms the interpreter and records the commit, runtime, rule count, partitions, pairs considered/skipped, verdict, median, and p95 for the actual host. Quote that artifact as one measurement, not as a product latency.

**“Does pairwise checking scale to 100,000 rules?”** Not as one unpartitioned set. Candidate pairs grow quadratically. This demo partitions conservatively using same-Thing, same-action-target, and writer-to-trigger interaction edges, exposes the work statistics, and tests up to its benchmark cases. A 100,000-rule deployment needs workload-specific partitioning and measurement.

**“Why not partition only by device?”** That would miss both rules bound to different sensors but writing one actuator, and cascades across devices when one action writes a property another rule reads. The partition graph therefore includes action-target and dependency edges and deliberately over-groups when uncertain.

**“Is this production proven?”** No. ExMaude and the repo are real code; this is a simulation and integration demo. State is in memory, the support broker is unsecured, and no production deployment evidence is presented.

## BeamLens diagnostics

**“Why BeamLens instead of Grafana?”** Grafana is useful when the operator already knows which panel and correlation to inspect. The stage question is diagnostic: “Why did alerts rise, which formal verdict accompanies the run, and what should I inspect next?” BeamLens selects bounded read-only callbacks, structures an answer, cites source fields, and separates observations from inference. Grafana remains the raw fallback.

**“Is the LLM deciding whether rules deploy?”** No. Maude returns the formal verdict and `Goatmire.Engine` owns activation. BeamLens can call only snapshot, current-verification, and recent-alert callbacks. There is no deployment or device command tool.

**“Can the model hallucinate?”** Yes. That is why the answer labels observations versus inference, cites fields, shows grounding/confidence, and keeps the structured snapshot visible. If prose conflicts with fields or the Maude verdict, the prose is wrong.

**“Why Codex?”** The installed Codex app-server exposes structured account, quota, thread, turn, and event APIs and can use the speaker's existing ChatGPT-plan login. The bridge starts an ephemeral read-only turn with no workspace or network access and extracts only the final structured diagnostic answer.

**“Does this use an API key or incur token charges?”** No API-key account is accepted, so the demo has no pay-per-token OpenAI API path. Codex requests still consume usage included in the signed-in ChatGPT plan. If plan auth or quota is unavailable, the dashboard shows the reason and uses local Ollama.

**“What data goes to OpenAI?”** With Codex, the operator's question and bounded diagnostic snapshot go to the signed-in service. The bridge does not send the repository workspace and disables network access for the turn. With Ollama, the prompt and snapshot stay on the laptop. The provider badge makes that boundary visible before prompting.

**“What if Codex is signed in with an API key?”** The bridge rejects the account type and falls back to Ollama. It also refuses Codex when the reported ChatGPT-plan quota is exhausted or spend controls say to stop.

**“Why this Ollama model?”** `qwen3.5:4b-q4_K_M` is fixed and installed before travel, so the fallback is a specific tested artifact rather than an unbounded “any local model” claim. Change it only after rerunning the diagnostic checks and rehearsal on the talk machine.

**“What happens if both providers fail?”** The formal demo still works. The diagnostics page shows unavailable status and the structured metric cards remain readable; Grafana or Prometheus can corroborate them. Never replace a missing Maude verdict with model prose.

**“Is BeamLens safe to expose publicly?”** This is a local stage application. Its diagnostic completion endpoint is loopback-only, callbacks are read-only, history and iterations are bounded, and no secrets are mounted into containers. That is a demo boundary, not a public-service security assessment.

## Simulation and adapters

**“Are those actual robots or sensors?”** No. Every stage device is simulated, and the counters are simulator counters. Generic MQTT, HTTP, Modbus, VDA 5050, and declared-device adapters remain in the repository as off-stage integration examples; they are not exercised or claimed as hardware support in the talk.

**“Why MQTT if the stage is simulated?”** The container rehearsal can preserve serialization, broker, and back-pressure boundaries while keeping every device simulated. If the support stack fails, local transport provides a simpler fallback without changing the formal rule term or deployment policy.

**“Is the VDA 5050 implementation compliant?”** No conformance claim is made. It implements a partial message and topic shape for an off-stage adapter example. It is absent from the proof claim and the live path.

## Adoption

**“How do I try the pattern?”** Start with a small predicate whose input you can validate. Add ExMaude and the Maude interpreter, encode the runtime rule term, preserve `unverified`, and test each translation and activation edge. Then benchmark your exact model and host. The repository's scenario and benchmark tasks make those decisions inspectable.

**“Do I need Phoenix, BeamLens, or an LLM?”** No. The gate is an Elixir call and works from CLI or Livebook. Phoenix makes the stage state visible. BeamLens and the model improve interactive diagnosis; they are outside the formal decision path.

## Honest fallback

**“I have a specific Maude or research-method question…”** “I don't know yet. I can show you the model and primary source, and I would rather follow up after checking than improvise a formal claim.”
