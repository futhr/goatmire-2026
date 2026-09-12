# Talk manuscript — plain-language 30-minute cut

This is the spoken reference for **“Zero Alert Storms: Formal Verification for IoT Automation.”** It follows the 25-slide stage deck at `/talk`.

The target is to finish the prepared talk in about 25–26 minutes. The remaining time is for silence while the room reads, a slow live action, recovery, or questions. This manuscript is a safety net, not a text to memorize word for word. Learn the seven-beat spine and each slide's first sentence; keep the complete text available for recovery.

Protect these lines:

> A bad answer, a good answer, and no answer are three different things.

> Maude made the decision. The language model explained what the system observed.

Stage directions are in italics and are not spoken.


The order matches [`slides/deck.md`](./slides/deck.md) and the live presenter.
Target starts below are cumulative rehearsal budgets, including the opening.
The presenter timer starts automatically on leaving the holding slide. Start
a separate rehearsal timer with the spoken opening for these full-talk targets,
or call `Goatmire.Talk.Clock.start_talk/0` at that point.

---

## 1 · Zero Alert Storms — 00:00

*(Let the room read the title. Look up.)*

Hi. I’m Tobias.

Today we are going to make two reasonable automation rules fight each other. Then we will stop the same conflict before either rule can run.

I have worked in software since 1998 and in IoT for eleven years. That has taught me one simple lesson: “be more careful” is not a deployment control.

---

## 2 · Both apps were reasonable — 00:40

This example comes from a published smart-home study called SOTERIA.

Its multi-app evaluation reports two apps, O3 and O4, responding to the same contact-open event with conflicting switch values.

This repository reproduces that rule shape in a controlled simulation. It is not a story about a real damaged home, and I am not claiming this code prevented the published result.

---

## 3 · Both rules are reasonable — 01:30

Each rule is easy to explain on its own.

A contact opens: O3 turns the switch on. The same contact opens: O4 turns the same switch off.

An isolated test can confirm that each app does what its author asked. The disagreement appears when we install both.

You review one change. The system runs all of them together.

---

## 4 · The loop nobody designed — 02:05

Nobody asked for the combined behavior on this slide.

The word composition means looking at what the rules do together. The O3/O4 example establishes conflicting writes; it does not by itself establish a repeating alert storm.

Later, the warehouse simulator will repeatedly activate a synthetic conflicting set so we can measure that separate effect.

Keep the published pattern and the simulated load distinct.

---

## 5 · Why wait until after deployment? — 02:40

The relationship between these rules exists before a device moves and before an alert fires.

Runtime monitoring still matters. But if we can see this conflict before deployment, why wait for telemetry to discover it afterwards?

The check belongs between “submit this rule” and “let this rule run.”

---

## 6 · Tests and checks answer different questions — 03:10

Why not solve this with more tests?

Tests are essential. They run the software and show what happened in selected cases. Property-based tests try many generated cases and often find surprises.

The formal checker asks a different question. It reads the rules before they run and asks: can these rules fight in one of the ways we defined?

That question is smaller than “is the whole system safe?” The smaller question is exactly why the answer can be stronger.

---

## 7 · Four pieces — 04:00

You need four Maude words to read the next slide.

Sorts describe types. Operators construct terms or name functions. Equations simplify terms. Rewrite rules describe possible state transitions.

For an Elixir developer, think of pattern-matched function clauses for simplification, and a state machine for transitions.

That distinction tells us which question a command can answer.

---

## 8 · Reduce is not search — 04:45

Reduce and search answer different questions.

`reduce` simplifies a term using equations. In the small switch example, toggling twice reduces to `on`. Our finite, validated conflict detector uses equations to compute its answer.

`search` explores transitions looking for a reachable state. A returned path is a witness. No witness within a bound is not an unbounded proof of safety; ExMaude's bounded safety and liveness helpers preserve `unverified`.

The IoT gate in this talk uses the equational detector, not an unrestricted search of every possible execution.

---

## 9 · Four conflict categories — 05:50

This demo checks four kinds of interaction.

Two rules can write opposite values. They can push the same environment in opposite directions. One rule can trigger another. Or that chain can cross between device state and the environment.

You do not need to remember the list. Remember the limit: if a problem is not represented here, this checker does not see it.

---

## 10 · A narrow claim can be strong — 06:40

So let’s say exactly what a clean result means.

It means this check completed and found none of these four conflict types in these rules.

It does not mean the whole installation is safe. It says nothing about a sensor mounted backwards, a late message, missing authorization, or a hazard we forgot to model.

That narrower sentence is less dramatic. It is also one I can defend.

---

## 11 · Maude as an ordinary supervised dependency — 07:25

Inside this Elixir application, Maude behaves like an ordinary dependency.

A supervised worker pool owns separate Maude processes. If one worker dies, its supervisor restarts it. The application call returns a normal tagged result.

The operational point is simple: formal checking does not have to live in a separate academic universe. It can sit inside the same failure-handling structure as the rest of the application.

---

## 12 · Verify the term the runtime executes — 08:10

This is the implementation choice I care about most.

The map on screen is the rule. The checker reads that map, and the runtime executes that same map.

If we checked a second handwritten copy, the copy could drift away from reality. Then we could prove something precise about the wrong rule.

Sharing the representation does not remove every translation risk, but it makes the boundary smaller and easier to test.

---

## 13 · Never turn “no answer” into “yes” — 09:00

The gate keeps three answers, not two.

`clean` means the check completed and found no conflict represented by this model.

`conflicts` means it found a concrete problem and names the rules involved.

`unverified` means it could not answer—for example because Maude was unavailable, the input was rejected, or the command timed out.

A bad answer, a good answer, and no answer are three different things.

This demo fails closed: an unverified rule is not deployed. That is an application policy we chose explicitly.

---

## 14 · Every arrow deserves a test — 10:05

Formal checking is only as trustworthy as the path around it.

The Elixir rule becomes an encoded rule. Maude produces text. The application turns that text into a typed answer and then into “deploy” or “stop.”

Every arrow deserves a test: validate the input, test the encoder, test the parser, and test what deployment does with all three answers.

---

## 15 · Partition on interaction edges — 10:45

Partitioning reduces the comparisons we ask Maude to make.

We join rules that share a Thing, write the same action target, or connect a writer to a trigger property. Grouping only by Thing would miss cross-Thing interactions.

The graph deliberately over-groups when uncertain. The resulting partitions still have to preserve every interaction the model can detect.

Read the rule, partition, and skipped-pair counts from the current run. A ratio from another corpus is not a scaling guarantee.

---

## 16 · Catch the conflict before the rule exists — 11:45

*(Reveal the Rules pane.)*

Now we will put the gate in the deployment path.

I’ll deploy the switch-on rule first. Then I’ll load the switch-off rule as the candidate and press “Check and create.”

*(Run the three scripted steps. Point to the answer and rule ids.)*

The answer is `state_conflict`, and it names both rules. The checker does not decide which rule is morally better. It only knows they disagree, so the gate stops the new combination and leaves that decision to a person.

The conflicting pair never exists in the active set.

*(Fallback: `mix goatmire.scenario 1`.)*

---

## 17 · Run the same shift change twice — 13:15

*(Reveal the Warehouse pane. Use the rehearsed fleet size.)*

Now we will run the same simulated shift change twice.

First is observe mode. The checker records the conflict but allows it to run so we can see the symptom.

*(Run Observe. Pause and read the displayed counters.)*

Those are measurements from this simulator, on this laptop, with the settings on screen. They are not a customer incident or a universal benchmark.

Now we reset and run with the same fleet, tick, and shift settings in enforce mode. Scheduling and random readings can differ between runs.

*(Run Enforce. Read the withheld rules and alert count.)*

The load did not disappear, and the broker did not become faster. The difference is earlier: the conflicting rules never reached activation.

The screen keeps the current verdict and counters together, so we can compare evidence from the same staged run.

---

## 18 · Ask the running system why — 16:30

*(Reveal Diagnostics. Point to the provider name.)*

We have numbers. Now let’s ask the running system to explain them.

The diagnostic tool receives a small, read-only snapshot. We ask why alerts rose, what formal answer came with the run, and what to inspect next.

*(Submit. Point to cited fields and the observation/inference split.)*

The observations point back to structured fields. Suggestions are labelled as inference. The provider name shows whether Codex or the local Ollama fallback produced the explanation. With Ollama the snapshot stays on this laptop; with Codex that limited context goes to the signed-in service.

Most importantly: Maude made the decision. The language model explained what the system observed. It cannot deploy a rule or change `conflicts` into `clean`.

---

## 19 · An LLM may propose policy; it should not judge itself — 18:10

The same boundary is useful when an LLM proposes a policy.

This structured invocation names a high-impact tool, a capability, and a jurisdiction. That data can be validated and passed to a separate deterministic policy model.

We are checking the emitted policy, not verifying the language model itself.

The author does not grade its own work.

---

## 20 · Exactly seven categories — 18:55

The AI-policy detector has exactly seven categories.

They are tool-call conflict, capability shadowing, pack/tool composition mismatch, sovereignty violation, authority escalation, approval-gate bypass, and agent-loop cascade.

The next live example focuses on approval and jurisdiction. It does not establish every possible policy property.

Budget, cost-ceiling, and provider-routing checks are not implemented results of this detector. If a property is not in the model, this detector did not check it.

---

## 21 · Put a deterministic gate around a probabilistic author — 19:40

A typed conflict gives the author something concrete to revise.

The optional generation scenario asks the configured model for structured rules, validates them, checks them, and can feed a conflict back for another attempt. It keeps the result of each completed pass.

A revised policy may still conflict, and generation may fail. There is no promise that a second attempt succeeds.

If the model is unavailable, show that failure and continue to the deterministic policy check.

---

## 22 · Approval missing → clean revision → wrong jurisdiction — 20:20

*(Reveal the Notebook pane.)*

This last demo has no fleet, broker, language model, or network. It is deliberately boring—and therefore a good recovery path.

First, a high-impact tool is used without approval. The checker reports `approval_gate_bypass`.

Then we add approval. The checker finds none of the conflict types it was asked to check.

Finally, we send an action to the US when the allowed regions are the EU and Switzerland. The answer is `sovereignty_violation`.

Three inputs. Three readable answers. The generated Maude command stays attached to the structured policy we just read.

---

## 23 · Maude is not the only answer — 23:00

Choose the tool that makes your property easiest to state precisely.

Maude fits algebraic terms and concurrent transitions. TLA+ or PlusCal can make temporal distributed behavior clearer. Alloy explores bounded relations; SMT tools such as Z3 solve constraints.

Types and protocol models can help with conformance. None removes the need to test the translation into the model.

Tool choice follows the property, not loyalty to this demo.

---

## 24 · Keep the claim attached to its evidence — 23:45

Before production, keep the claim attached to its evidence.

Validate inputs, test the translation steps, bound checking work, and recover uncertain workers. Record which model, interpreter, validated input, verdict, and activation decision belong together.

Those are engineering requirements, not a claim that this demo is production proven. Its state is in memory, its broker is a trusted local support service, and the fleet is simulated.

An audit artifact supports review. It does not automatically satisfy a regulation or prove an omitted property.

---

## 25 · Formal methods make a narrow claim strong — 24:35

The code, notebooks, and demo are available if you want to try this pattern.

Please take away three things.

First: check rules together before deployment, because reasonable rules can become unreasonable together.

Second: keep `clean`, `conflicts`, and `unverified` separate. Never turn “I could not check” into “yes.”

Third: check the same rule the runtime will execute, and test every translation step around it.

Formal methods make a narrow claim strong. They do not make a broad claim true.

Thank you.

*(Stop. Let the ending stand.)*

---

## Hard-cut map

- On slides 7–9, keep the four-word vocabulary, reduce/search distinction, and model boundary; omit elaboration.
- On slide 15, name the three interaction edges and read only the current partition count.
- On slide 18, protect the observation/inference sentence and the Maude/LLM boundary.
- If LIVE 04 (slide 22) would start after 23:30, skip it and use one sentence each on tool choice (23) and production limits (24).
- Begin the close (25) no later than 26:00. Keep the three takeaways and final scope sentence.
