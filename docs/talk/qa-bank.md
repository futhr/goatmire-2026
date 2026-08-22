# Q&A Bank

Answers are intentionally narrower than the most tempting stage claim. When a question exceeds the evidence, name the boundary and follow up rather than inventing certainty.

## Research case and claims

**“Did this actually happen?”** The contact-open pair is a controlled reproduction of a conflict shape reported in SOTERIA's multi-app evaluation: O3 and O4 set a switch to conflicting values for the same event. The demo does not claim any real home was harmed, or that this code prevented the published result. The warehouse alert storm is synthetic behavior used to compare deployment modes.

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

**“Why is the check synchronous, inside the request?”** Because the property is about the set the rule is joining, and that set is only known at deployment time. The check runs between “submit” and “exists,” its measured duration is printed on every result, and a slow answer is still an answer — a timeout becomes `unverified` and deploys nothing.

**“Couldn't you write these four predicates in plain Elixir?”** For the direct state conflict, honestly, yes. The value is the discipline around it: the same validated term goes to an independent decision procedure, cascade witnesses come from search rather than hand-rolled graph traversal, and the runtime evaluator stays a separate implementation from the checker. When checker and runtime share code, they share bugs.

**“Why refuse instead of resolving with priorities?”** A priority picks a winner without knowing intent. The rule shape carries a priority field, but the reproduced pair has equal priority and different authors — and at runtime, action order would silently make the last write win, which is exactly the behavior the check exists to surface. The gate refuses and asks a human to resolve intent.

**“Why plain maps with tuple triggers instead of structs?”** The rule is data that crosses a translation boundary. One plain term with a closed trigger grammar is what the validator checks, the encoder translates, and `RuleEval` executes — three consumers, one representation. A struct would be a fourth representation to keep honest.

## Performance and scale

**“How fast is it?”** There is no responsible universal number. The repository benchmark warms the interpreter and records the commit, runtime, rule count, partitions, pairs considered/skipped, verdict, median, and p95 for the actual host. Quote that artifact as one measurement, not as a product latency.

**“Does pairwise checking scale to 100,000 rules?”** Not as one unpartitioned set. Candidate pairs grow quadratically. This demo partitions conservatively using same-Thing, same-action-target, and writer-to-trigger interaction edges, exposes the work statistics, and tests up to its benchmark cases. A 100,000-rule deployment needs workload-specific partitioning and measurement.

**“Why not partition only by device?”** That would miss both rules bound to different sensors but writing one actuator, and cascades across devices when one action writes a property another rule reads. The partition graph therefore includes action-target and dependency edges and deliberately over-groups when uncertain.

**“Can the gate run on constrained edge hardware?”** Not demonstrated. Maude and the simulated fleet run on the demo laptop and support containers; no ARM board or constrained runtime is benchmarked here. What the repo gives you is `mix goatmire.benchmark`, which records host, versions, corpus, and distribution — so an edge claim can come from your measurement on your hardware, not from this stage.

**“Is the partitioning itself tested?”** Yes, with property tests: generated rule sets must partition losslessly with every interaction edge kept inside one component, and the pairs-considered/skipped arithmetic must add up. The soundness of skipping pairs depends entirely on those edges, so they are tested harder than the happy path.

**“Is this production proven?”** No. ExMaude and the repo are real code; this is a simulation and integration demo. State is in memory, the support broker is unsecured, and no production deployment evidence is presented.

## Running it on the BEAM

**“Isn't a single GenServer engine a bottleneck?”** It serializes deploys and event ingestion on purpose: an activation decision needs a consistent view of the deployed set. The stress suite drains 20,000 concurrent transport events through it without mailbox growth on the bench machine. That is a measured demo bound, not a throughput claim.

**“Two operators submit conflicting rules at the same time?”** Admissions serialize through the engine process, so each candidate is verified against the set it actually joins. There is no window where both pass against a stale set on one node. Multi-node admission coordination is not claimed.

**“Does it cluster?”** The fleet does; the gate deliberately does not. `Goatmire.LocalCluster` boots up to sixteen peer BEAM nodes on one machine over Erlang distribution, each running the simulator role with its own fleet partition — its own docs say it shows the partitions, not that anything survives a datacentre. The container swarm distributes simulators with a real broker between them. In both, verification and admission stay on the single engine node, because serialized admission is what makes “checked against the set it joins” true. A distributed gate would need admission coordination that is neither built nor claimed here.

**“Aren't those peer nodes just faking distribution?”** They share one kernel and one network stack, and the module says so. They demonstrate that fleet partitions boot, connect, and report independently — a laptop-scale rehearsal of the topology. Datacentre survival claims need the broker-separated container setup and real failure injection, and this talk makes neither claim.

**“What happens to an in-flight reduction when a worker dies?”** The caller gets an error, the error becomes `unverified`, and nothing deploys. The pool replaces the worker; interpreter starts, timeouts, and crashes are counted in telemetry, and a worker is restarted after a timeout because its interpreter state is uncertain.

**“Why four workers and no overflow?”** `pool_size: 4, pool_max_overflow: 0` keeps the worst case bounded: extra concurrent callers wait or time out instead of spawning interpreters until the machine swaps. Saturation shows up as checkout latency and honest `unverified`s — the starvation stress test asserts every outcome under saturation is still a verdict, never a hang.

**“Poolboy? Why not NimblePool?”** The pool is ExMaude's; the consumer contract is a child spec and named, isolated pools. Which pool library sits underneath is the library's implementation detail, and the demo depends only on the contract.

**“Does a demo crash take down the talk?”** The supervision tree splits a talk-critical branch from the demo domain. A crash-looping demo component exhausts its own branch's restart budget, that branch restarts, and the endpoint and presenter clock hold position. That property is chaos-tested, not asserted.

**“What telemetry does it actually emit?”** Verification stop events with duration, status, and scenario; engine event, alert, throttle, and deploy counters; ExMaude pool checkout and server lifecycle events. The Prometheus exporter and the in-app diagnostic sampler read the same events, so the charts and the BeamLens answers cite the same evidence.

## Generated policies

**“What stops a hostile generated rule — prompt injection into the term?”** Generated output is decoded and validated before it is encoded: identifiers are checked, strings pass through the library encoder, and atoms are never created from untrusted input. A rule that fails validation is `unverified`, and `unverified` deploys nothing. That is input hygiene, not a jailbreak-resistance claim.

**“Why feed the verdict back to the model instead of fixing the rule in code?”** A typed conflict is a better revision prompt than “try again.” The loop is bounded — two generate-and-verify rounds by default — every pass is kept with its verdict, and a set that never comes back clean simply never deploys.

## BeamLens diagnostics

**“Why BeamLens instead of Grafana?”** Grafana is useful when the operator already knows which panel and correlation to inspect. The stage question is diagnostic: “Why did alerts rise, which formal verdict accompanies the run, and what should I inspect next?” BeamLens selects bounded read-only callbacks, structures an answer, cites source fields, and separates observations from inference. The in-app Metrics pane carries the raw series; Grafana is not part of this rig.

**“Is the LLM deciding whether rules deploy?”** No. Maude returns the formal verdict and `Goatmire.Engine` owns activation. BeamLens can call only snapshot, current-verification, and recent-alert callbacks. There is no deployment or device command tool.

**“Can the model hallucinate?”** Yes. That is why the answer labels observations versus inference, cites fields, shows grounding/confidence, and keeps the structured snapshot visible. If prose conflicts with fields or the Maude verdict, the prose is wrong.

**“Why Codex?”** The installed Codex app-server exposes structured account, quota, thread, turn, and event APIs and can use the speaker's existing ChatGPT-plan login. The bridge starts an ephemeral read-only turn with no workspace or network access and extracts only the final structured diagnostic answer.

**“Does this use an API key or incur token charges?”** No API-key account is accepted, so the demo has no pay-per-token OpenAI API path. Codex requests still consume usage included in the signed-in ChatGPT plan. If plan auth or quota is unavailable, the dashboard shows the reason and uses local Ollama.

**“What data goes to OpenAI?”** With Codex, the operator's question and bounded diagnostic snapshot go to the signed-in service. The bridge does not send the repository workspace and disables network access for the turn. With Ollama, the prompt and snapshot stay on the laptop. The provider badge makes that boundary visible before prompting.

**“What if Codex is signed in with an API key?”** The bridge rejects the account type and falls back to Ollama. It also refuses Codex when the reported ChatGPT-plan quota is exhausted or spend controls say to stop.

**“Why this Ollama model?”** `qwen3.5:4b-q4_K_M` is fixed and installed before travel, so the fallback is a specific tested artifact rather than an unbounded “any local model” claim. Change it only after rerunning the diagnostic checks and rehearsal on the talk machine.

**“What happens if both providers fail?”** The formal demo still works. The diagnostics page shows unavailable status and the structured metric cards remain readable, and the Metrics pane carries the raw series. Never replace a missing Maude verdict with model prose.

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
