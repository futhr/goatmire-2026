# Talk script — 30-minute stage cut

This is the rehearsable script for **“Zero Alert Storms: Formal Verification for IoT Automation.”** It matches the 25-slide source in [`slides/deck.md`](./slides/deck.md).

The target is 27:30, leaving 2:30 for a slow transition, a failed demo command, or a room that laughs longer than expected. Do not spend that margin in the first rehearsal. Scenario 4 uses the configured model only after its health check is green; otherwise skip that authoring beat and continue with the deterministic policy check. Physical hardware is not part of this stage cut.

The sentence to protect when cuts are needed is:

> A bad answer, a good answer, and no answer are three different things.

Stage directions are in italics and are not spoken. Text marked **CUT** can be dropped without damaging the argument.

---

## 1 · Zero Alert Storms — 00:00

*(Let the room read the title. Look up before speaking.)*

Good morning.

In the next thirty minutes, we are going to create an alert storm, watch two perfectly reasonable automation rules fight each other, and stop the same storm before either rule can run.

The prevention will not be heroic. It will be mechanical.

I’m Tobias Bohwalli. I’ve worked in software since 1998 and in IoT for eleven years. That is long enough to have learned that “be more careful” is not a deployment control.

---

## 2 · Both apps were reasonable — 00:40

Let's start with a conflict shape reported by SOTERIA, a published smart-home safety analysis.

In its multi-app evaluation, two applications identified as O3 and O4 respond to the same event—a contact sensor opening—and set the same switch to conflicting values.

This repository reproduces that rule shape. The source is inspectable, the pair is exact enough to name, and the boundary is visible: published interaction, controlled simulation. I am not claiming a harmed household or historical prevention.

---

## 3 · One event, one switch, two values — 01:35

Let's read the two rules as domain statements.

The first reproduced rule says: when the contact sensor is open, set the switch to `on`.

The second says: when that same contact sensor is open, set the same switch to `off`.

Same event. Same device and property. Incompatible values. Neither rule has to look malformed in isolation for the composition to be wrong.

That is why code review alone is a weak control here. You usually review one change. The system runs the set.

---

## 4 · Composition is the bug — 02:15

SOTERIA's example is a direct state conflict. Other research, including HOMEGUARD and IoTCheck, reaches the same systems lesson from different formal models: applications that are acceptable alone can interfere when installed together.

Our later warehouse storm is synthetic. It deliberately repeats a conflicting activation so that we can measure the operational symptom—an alert rate. The research establishes the interaction pattern; the demo establishes what this implementation does with it.

Every component can work while the composed system is absurd.

---

## 5 · The deployment question — 03:00

The relationship between those rules existed before the first robot moved.

So why should we wait for telemetry to discover it?

Runtime monitoring is still essential. We can move one class of discovery earlier—to the moment between “submit this rule” and “this rule now exists.”

---

## 6 · Sample behaviour or decide a predicate — 03:35

Testing and formal checking are not enemies. They answer different questions.

When you run a unit test or simulation, you ask whether these executions behaved correctly. Property-based testing lets you explore many generated cases and is excellent at finding surprising runtime behaviour.

An equational conflict detector asks a narrower question: for this validated, finite term, does the encoded conflict predicate hold?

We can make the second claim stronger because it is narrower. It says nothing about physics, timing, firmware, or properties we did not encode.

**CUT:** Tests can also be exhaustive over a finite domain. The distinction is not “random versus mathematical.” It is which claim the tool actually supports.

---

## 7 · A Maude mental model — 04:35

We need only four pieces of Maude vocabulary.

Sorts are types. Operators are constructors and functions. Equations describe deterministic simplification. Rewrite rules describe possible state transitions.

For an Elixir developer, equations feel like complete pattern-matching function clauses applied until the value cannot simplify further. Rewrite rules feel more like the possible transitions of a state machine.

That analogy is incomplete, but it is enough to read the next two commands.

---

## 8 · Reduce is not search — 05:30

`reduce` applies equations and returns a normal form.

Here, toggling `on` twice reduces back to `on`.

`search` explores transitions. If it finds `ready` reachable from `idle`, that path is a concrete witness in the model.

You can use these for different conclusions. And we need to name one trap now: no witness inside a depth bound is not an unbounded safety or liveness proof. In this project, a bounded search that exhausts its bound without a witness is reported as `unverified`, not quietly relabelled `safe`.

---

## 9 · Four conflict categories — 06:30

In this demo, you will see the IoT detector check four categories.

A state conflict is the direct case we just saw: incompatible writes to the same Thing and property.

An environment conflict is two actions pushing a shared environmental property apart.

A state cascade is one rule’s action satisfying another rule’s trigger.

And a state–environment cascade crosses those two domains.

This is a smaller custom model inspired by published categories. It is not a complete model of an industrial site, and it is not an implementation of an entire external research system.

---

## 10 · A narrow claim can be strong — 07:30

Let's draw the border around the claim.

Inside it: validated finite rules, the encoder, the selected Maude module, and the interpreter result.

Outside it: mechanical clearance, sensor calibration, firmware timing, authorization, omitted hazards, and the physical deployment.

So when the result is empty, we will not say “the system is safe.” We will say: “this detector found none of its four modelled conflict types in this input.”

That sentence is less dramatic. It is also a sentence I can defend.

---

## 11 · Maude as a supervised dependency — 08:25

ExMaude makes the interpreter look like an ordinary Elixir dependency while keeping the operational boundary explicit in your supervision tree.

The application owns a named worker pool in its supervision tree. Each worker maintains a Maude session in a separate operating-system process. The default backend talks over plain pipes.

The public call on screen returns a tagged tuple, just like the rest of our Elixir code.

There are also C-node and NIF-backed transports. I am not going to claim one is universally faster. Choose with a reproducible workload and the failure blast radius you are prepared to own.

---

## 12 · Verify the term the runtime executes — 09:30

Watch this implementation detail; it is the centre of the demo.

The map on the left is not documentation for a second rule representation. It is the rule.

`Goatmire.Rules` produces it. We feed it through ExMaude’s encoder for the detector, and `Goatmire.Engine.RuleEval` executes the same map at runtime.

A verified copy that drifts from runtime proves the wrong thing precisely.

Sharing the term does not remove the translation boundary, but it makes that boundary small enough to test hard.

---

## 13 · Never turn “no answer” into “yes” — 10:30

We keep three answers at the gate, not two.

`clean`: the detector ran and found no conflict represented by its model.

`conflicts`: it returned a concrete typed conflict, including the rules that participate.

`unverified`: the detector did not produce a verdict—perhaps the interpreter is unavailable, the encoder rejected the input, or the command timed out.

A bad answer, a good answer, and no answer are three different things.

This demo fails closed. If the result is unverified, nothing is admitted. That is an application policy, not a magical property of the library, and your activation layer must own that decision explicitly.

---

## 14 · Every arrow deserves a test — 11:45

If you remember one engineering warning, remember that the real trust boundary is longer than the Maude command.

Validated Elixir data becomes an encoded term. The term runs in a selected module and interpreter. Text output becomes a typed verdict. The application turns that verdict into an activation decision.

Every arrow deserves a test.

Validate identifiers before encoding. Escape through the encoder rather than interpolating user text. Test that the selected module is the one you think it is. Test the parser. Test `unverified`. Test what deployment does with each state.

Formal reasoning over mistranslated input is still wrong.

---

## 15 · Partition on interaction edges — 12:45

We do not need one large reduction when most rules cannot interact.

But if we grouped only by Thing, the result would be unsound. A cascade can cross Things by definition: one device writes a property that another rule reads.

We build connected components using three conservative edges: same Thing, same action target, and writer-to-trigger property. Then we verify each component and merge the verdicts. Any unverified partition makes the whole result unverified.

The dashboard shows the actual rule count, partition count, and skipped pairs. I will read those numbers rather than turn one laptop run into a universal ratio.

---

## 16 · LIVE 01 — Catch the conflict — 13:45

*(Switch to `http://localhost:4000/rules/new`.)*

This is the rule-creation request. The pair is labelled research-derived on screen: our rule IDs reproduce SOTERIA's O3/O4 contact-open conflict shape.

I’ll deploy the switch-on rule as the existing rule, then load the switch-off rule as the candidate. Now I press “Check and create.”

*(Run it. Point to the verdict, then the rule ids.)*

The gate returns `state_conflict` and names both reproduced rule IDs. You can see what it does not do: it does not guess that safety outranks operations or that the newer author must be right. It knows the rules disagree, so it refuses the deployment and asks a human to resolve intent.

The conflicting combination never exists in the active set.

*(Fallback: run `mix goatmire.scenario 1`.)*

---

## 17 · LIVE 02 — Run the shift twice — 15:15

*(Switch to `/warehouse`. Use the rehearsed fleet size.)*

This floor is a visual sample. At large fleet sizes it deliberately renders at most five hundred devices so the browser does not become the bottleneck. The engine counters still cover the complete fleet.

First, we run the same shift change in observe mode.

*(Run. Let the count move. Read the displayed result.)*

That is the measured output of this simulator, on this machine, at the fleet size and tick rate on screen. It is not a customer incident and not a portable benchmark.

Observe mode records the verdict but deliberately lets known conflicts deploy. It exists to give this controlled comparison—not as a recommended production setting.

Now we reset and run the same staged shift in enforce mode.

*(Run. Read the withheld rules and alert count.)*

The load did not disappear. The broker did not get faster. The difference is that the conflicting pair never reached activation.

The result includes the formal verdict, partitions, pairs considered, pairs skipped, and the counters from this run. Prometheus retains the raw series; we will use it only as corroboration after asking the running system directly.

---

## 18 · LIVE 03 — Ask the running system why — 18:15

*(Open `/diagnostics`. Point to the active provider badge before prompting.)*

This page uses our read-only BeamLens skill, not a static dashboard. The skill supplies a bounded snapshot of the last five minutes: engine rates and alerts, the current Maude verdict and witness, partition work, ExMaude pool health, fleet size, and BEAM runtime pressure.

Let's ask: “Why did alerts rise in the last minute, what formal verdict accompanies this run, and what should I inspect next?”

*(Submit. Point to cited fields, then the observation/inference split.)*

The observations cite structured fields. Inference is labelled separately, with grounding and confidence. You can see in the provider badge whether this answer came from Codex using my existing ChatGPT-plan allowance or the fixed local Ollama fallback—and it shows why a fallback occurred.

No API-key account is accepted, so this demo does not create pay-per-token API charges. Codex still consumes included plan usage. With Ollama, the prompt and snapshot stay on this laptop; with Codex, that bounded diagnostic context goes to the signed-in service.

Most importantly: Maude made the deterministic conflict decision. The language model explained the snapshot. It cannot deploy a rule, operate a device, or turn `conflicts` into `clean`.

*(If both providers fail, read the structured cards. Open Grafana only to corroborate one field.)*

---

## 19 · An LLM should not judge itself — 19:20

Now let's change the policy domain.

An LLM may propose structured automation or agent policy. It should not be the final judge of the policy it just proposed.

This term invokes a dosing tool with a `high_impact` capability in the EU. It contains no explicit approval constructor.

We are not verifying an LLM. We are checking validated structured output produced by one. Different model, same engineering path.

---

## 20 · Exactly seven categories — 20:10

Here you get exactly seven categories: tool-call conflict, capability shadowing, pack/tool composition mismatch, sovereignty violation, authority escalation, approval-gate bypass, and agent-loop cascade.

Exactly seven is more important than an impressive “AI safety” label.

Budget cascade, cost-ceiling feasibility, and provider-routing feasibility are not public detector results here. If the property is not in this list, this detector did not check it.

---

## 21 · A deterministic gate around a probabilistic author — 21:00

The loop is simple. We generate structured rules, validate and encode them, return a typed conflict, feed that conflict into a revision, and verify again.

If no language model is reachable on stage, we keep that failure visible and skip the authoring beat. The deterministic policy check on the next slide still demonstrates the gate without pretending a canned response was live.

The valuable boundary is not “AI versus no AI.” It is probabilistic author, deterministic policy gate.

---

## 22 · LIVE 04 — The policy by hand — 22:00

*(Open Scenario 5 in Livebook.)*

Nothing moves in this notebook. No fleet, no broker, no language model, no network. That makes it the recovery path for the entire talk.

First: high impact, no approval.

*(Run. Read `approval_gate_bypass`.)*

Now we add an explicit approval constructor before the invocation.

*(Run. Read the empty list and immediately narrow it.)*

This detector found none of its seven modelled conflicts.

Finally, I route an invocation to the US while the allowed set is EU and Switzerland.

*(Run. Read `sovereignty_violation`.)*

And this final cell shows the raw Maude command generated by the real encoder. It is not a hand-copied command made to look convincing. Documentation that imitates an encoder will drift; generated evidence stays attached to the term we just read.

---

## 23 · Maude is not the only answer — 24:00

You should choose a formal tool by the shape of the property.

Maude is a natural fit for algebraic terms and concurrent transitions.

TLA+ is often a better fit for temporal behaviours in distributed systems. Alloy is excellent for bounded relational structures. An SMT solver such as Z3 is powerful for constraints and satisfiability. Types and protocol-specific model checkers may give a clearer answer elsewhere.

Tool loyalty is not a verification strategy. Choose the model that makes the property clearest and the translation easiest to distrust constructively.

---

## 24 · Keep the claim attached to its evidence — 25:10

Before you take this pattern toward production, do the unglamorous work.

Validate input. Test every translation edge. Bound pool size, checkout time, command time, and search depth. Restart a worker after timeout because its interpreter state may be uncertain. Keep independent consumers in independent named pools.

For an audit artifact, record the model revision, interpreter version, validated input, typed result, duration, and activation decision.

That artifact can be valuable engineering evidence. It does not automatically satisfy a regulation; that needs a separate control mapping.

---

## 25 · Close — 26:25

The library, demo, Docker stack, notebooks, and this deck are open if you want to try the pattern.

I want you to take away three things.

First: inspect rule composition before activation, because reasonable local decisions can create an unreasonable system.

Second: preserve all three answers—clean, conflicts, and unverified. Never turn “I could not check” into “yes.”

Third: verify the same term the runtime executes, and test every translation edge around it.

Formal methods make a narrow claim strong. They do not make a broad claim true.

Thank you.

*(Stop. Do not add a second ending.)*

---

## Hard-cut map

If the clock is late:

- At 06:00, cut the middle paragraph of slide 8; keep the bounded-search caveat — it is the talk's central honesty point.
- At 10:00, cut backend variants on slide 11.
- At 13:00, say only the first and last paragraphs of slide 15.
- Never cut the three-verdict slide.
- At 19:00, skip from LIVE 03 to slide 21.
- At 24:30, compress slide 23 to “choose by property shape.”
- Begin the close no later than 27:15.
