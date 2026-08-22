# Memorize the talk — anchors, beats, exits

This is the memorization cut of [`manuscript.md`](./manuscript.md). Same words, different structure: every slide has an **anchor** (the opening line — learn these verbatim, they restart you anywhere you blank), the full **say** text, three-to-five **beats** (the middle, as cues — improvise around them, don't recite), and an **exit** line that bridges into the next slide. Transitions are what people actually forget, so the exits and anchors are the drill.

## How to learn it

1. Read the whole doc aloud twice. Don't memorize yet — let the argument order settle.
2. Drill the **spine** below until you can say all 25 lines cold, in order. That's the talk in one breath per slide.
3. Drill **anchors + exits** only. If you know how every slide starts and ends, the middles rebuild themselves from the beats.
4. Full runs against `/talk` with the timer. When you blank: say the anchor of the current slide out loud — it reboots the slide.
5. Protect one sentence above all cuts: **“A bad answer, a good answer, and no answer are three different things.”**

The hard-cut map lives at the end of `manuscript.md`. The timer starts when you leave slide 1.

## The spine — one line per slide

1. The prevention will not be heroic. It will be mechanical.
2. Two apps, same event, same switch, opposite values.
3. You review one change. The system runs the set.
4. Every component can work while the composed system is absurd.
5. Why wait for telemetry to discover it?
6. Tests sample behaviour; the detector decides a predicate.
7. Four words of Maude, each with an Elixir cousin.
8. Reduce decides. Search finds witnesses. No witness is not “safe.”
9. Four categories: state, environment, cascade, state–environment.
10. Less dramatic — and a sentence I can defend.
11. A worker pool, the same way you own a database pool.
12. Verify the term the runtime executes.
13. A bad answer, a good answer, and no answer are three different things.
14. Every arrow deserves a test.
15. Cluster what could touch; one unverified cluster poisons the whole.
16. The conflicting combination never exists in the active set.
17. Same load, same broker — the pair never reached activation.
18. Maude decided. The model explained.
19. The LLM may propose; it does not judge itself.
20. Exactly seven, and nothing else.
21. Probabilistic author, deterministic gate.
22. Nothing moves in this notebook — the recovery path.
23. Choose the tool by the shape of the property.
24. Keep the claim attached to its evidence.
25. Narrow claim strong. Broad claim not true.

---

## ACT I — The problem (slides 1–5, ~3:00)

Deck only, full width. No panel, no timer until you leave slide 1.

### 1 · Zero Alert Storms — 00:00 · 40s

Do: let the room read the title. Look up before speaking.

**Anchor:** “Hi.”

Say:

> In the next thirty minutes, we are going to create an alert storm, watch two perfectly reasonable automation rules fight each other, and stop the same storm before either rule can run.
>
> The prevention will not be heroic. It will be mechanical.
>
> I’m Tobias Bohwalli. I’ve worked in software since 1998 and in IoT for eleven years. That is long enough to have learned that “be more careful” is not a deployment control.

Beats: create a storm → stop the same storm → mechanical, not heroic → since 1998, IoT eleven years.

**Exit:** “…‘be more careful’ is not a deployment control.”

### 2 · Both apps were reasonable — 00:40 · 50s

**Anchor:** “Let's start with a conflict that researchers actually found in the wild.”

Say:

> A published smart-home safety study called SOTERIA looked at what happens when several automation apps share one house. Two of those apps — the paper calls them O3 and O4 — react to the same event, a contact sensor opening, and set the same switch to opposite values.
>
> This repository reproduces that rule shape. The source is inspectable, the pair is exact enough to name, and the boundary is visible: published interaction, controlled simulation. I am not claiming anyone's home was harmed, or that this code prevented the published result.

Beats: SOTERIA, several apps, one house → O3 + O4, same event, opposite values → reproduced shape, honest boundary.

**Exit:** “…or that this code prevented the published result.”

### 3 · One event, one switch, two values — 01:35 · 35s

**Anchor:** “Let's read the two rules as plain sentences.”

Say:

> The first one says: when the contact sensor is open, set the switch to `on`.
>
> The second says: when that same contact sensor is open, set the same switch to `off`.
>
> Same event. Same device and property. Incompatible values. Neither rule looks wrong on its own — the composition is what's wrong.
>
> That is why code review alone is a weak control here. You review one change. The system runs the set.

Beats: rule one `on` → rule two `off` → neither wrong alone → review one change, run the set.

**Exit:** “You review one change. The system runs the set.”

### 4 · Composition is the bug — 02:15 · 40s

**Anchor:** “SOTERIA's example is a direct state conflict.”

Say:

> Other research groups, using different formal models, keep landing on the same lesson: apps that are acceptable alone can interfere the moment they're installed together.
>
> Our later warehouse storm is synthetic. It deliberately repeats a conflicting activation so we can measure the operational symptom — an alert rate. The research establishes the interaction pattern; the demo shows what this implementation does with it.
>
> Every component can work while the composed system is absurd.

Beats: other groups, same lesson → our storm is synthetic, measures the symptom → research = pattern, demo = this implementation.

**Exit:** “Every component can work while the composed system is absurd.”

### 5 · The deployment question — 03:00 · 35s

**Anchor:** “Here's the thing: the relationship between those two rules existed before the first robot moved.”

Say:

> So why should we wait for telemetry to discover it?
>
> Runtime monitoring is still essential. But one class of discovery can move earlier — to the moment between “submit this rule” and “this rule now exists.”

Beats: relationship existed before motion → monitoring still essential → move discovery to submit-vs-exists.

**Exit:** “…between ‘submit this rule’ and ‘this rule now exists.’” *(The next slide answers the objection everyone just thought of.)*

---

## ACT II — The tool (slides 6–10, ~4:25)

Split view. Right panel shows the code card for each slide — point at it when the beat lands.

### 6 · Sample behaviour or decide a predicate — 03:35 · 55s

**Anchor:** “At this point, every senior engineer in the room is thinking: why not just write more tests?”

Say:

> Fair question. Testing and formal checking are not enemies — they answer different questions.
>
> A test runs your code and checks what happened. Property-based testing runs it across many generated cases, and it is excellent at finding surprising runtime behaviour. Both of them *sample*.
>
> The conflict detector never runs the system at all. It takes the finite, validated rule set and *computes* the answer to one narrow question: do these rules conflict, in the ways my model defines conflict? It can answer yes-or-no the way an exhaustive `case` over a closed enum can't miss a branch.
>
> The narrower question is what makes the answer stronger. And it says nothing about physics, timing, firmware, or anything we did not encode.

Beats: not enemies, different questions → tests sample → detector computes, never runs → exhaustive `case` analogy → narrow is what makes it strong.

CUT (droppable): tests can also be exhaustive over a finite domain — the distinction is which claim the tool supports.

**Exit:** “…nothing about physics, timing, firmware, or anything we did not encode.”

### 7 · A Maude mental model — 04:35 · 50s

**Anchor:** “So what is Maude? You need exactly four words of it, and each one has an Elixir cousin.”

Say:

> A sort is a type. An operator is a constructor or a function. An equation simplifies a term — like pattern-matched function clauses applied until the value cannot simplify any further. A rewrite rule is a possible state transition — think state machine, not function.
>
> That analogy is incomplete, but it is enough to read the next two commands.

Beats: sort = type → operator = constructor/function → equation = function clauses to a fixpoint → rewrite rule = state machine.

**Exit:** “…enough to read the next two commands.”

### 8 · Reduce is not search — 05:30 · 55s

**Anchor:** “`reduce` runs the equations until the term settles.”

Say:

> Deterministic, like calling a pure function. Here, toggling `on` twice reduces back to `on`.
>
> `search` walks the transitions, looking for a state you asked about. If it finds `ready` reachable from `idle`, that path is a concrete witness in the model.
>
> Two commands, two different kinds of conclusion. And we need to name one trap now: a search that explores up to some depth and finds nothing has *not* proven the system safe — it only looked that far. In this project, a bounded search that exhausts its bound without a witness is reported as `unverified`, never quietly relabelled `safe`.

Beats: reduce = pure function, toggle twice → search = walk transitions, concrete witness → the trap: empty bounded search ≠ safe → reported `unverified`.

**Exit:** “…reported as `unverified`, never quietly relabelled `safe`.”

### 9 · Four conflict categories — 06:30 · 55s

**Anchor:** “In this demo, you will see the IoT detector check four categories.”

Say:

> A state conflict is the direct case we just saw: incompatible writes to the same Thing and property.
>
> An environment conflict is two actions pushing a shared environmental property apart.
>
> A state cascade is one rule's action satisfying another rule's trigger — a chain reaction.
>
> And a state–environment cascade is that same chain crossing between device state and the environment.
>
> This is a smaller custom model inspired by published categories. It is not a complete model of an industrial site, and it is not an implementation of an entire external research system.

Beats: state = the case we saw → environment = pushed apart → cascade = chain reaction → crossing chain → smaller custom model, honest scope.

**Exit:** “…not an implementation of an entire external research system.”

### 10 · A narrow claim can be strong — 07:30 · 50s

**Anchor:** “Let's draw the border around the claim.”

Say:

> Inside it: validated finite rules, the encoder, the selected Maude module, and the interpreter result.
>
> Outside it: mechanical clearance, sensor calibration, firmware timing, authorization, omitted hazards, and the physical deployment.
>
> So when the result is empty, we will not say “the system is safe.” We will say: “this detector found none of its four modelled conflict types in this input.”
>
> That sentence is less dramatic. It is also a sentence I can defend.

Beats: inside: rules, encoder, module, result → outside: physics, timing, auth, hazards → the exact sentence we say instead of “safe.”

**Exit:** “That sentence is less dramatic. It is also a sentence I can defend.”

---

## ACT III — The engineering (slides 11–15, ~4:55)

Still split with code cards. This act is for the BEAM crowd — slow down, this is home turf.

### 11 · Maude as a supervised dependency — 08:25 · 60s

**Anchor:** “What does this cost operationally? Less than you'd fear.”

Say:

> ExMaude makes the interpreter look like an ordinary Elixir dependency. The application owns a named worker pool in its supervision tree — the same way it owns a database pool. Each worker keeps one Maude session alive in a separate operating-system process, and if a worker dies, the supervisor restarts it like any other child.
>
> The public call on screen returns a tagged tuple, just like the rest of our Elixir code.
>
> There are also C-node and NIF-backed transports. I am not going to claim one is universally faster. Choose with a reproducible workload and the failure blast radius you are prepared to own.

Beats: like a database pool → separate OS process, supervisor restarts → tagged tuple → no universal ranking, choose by blast radius.

**Exit:** “…the failure blast radius you are prepared to own.”

### 12 · Verify the term the runtime executes — 09:30 · 55s

**Anchor:** “Watch this implementation detail; it is the centre of the demo.”

Say:

> The map on the left is not documentation for a second rule representation. It is the rule.
>
> `Goatmire.Rules` produces it. We feed the same map through ExMaude's encoder for the detector, and `Goatmire.Engine.RuleEval` executes it at runtime.
>
> Why does that matter? Because a verified copy that drifts from what actually runs proves the wrong thing precisely.
>
> Sharing the term does not remove the translation boundary, but it makes that boundary small enough to test hard.

Beats: the map IS the rule → encoder checks it, RuleEval runs it → drifted copy proves the wrong thing precisely → boundary small enough to test hard.

**Exit:** “…small enough to test hard.”

### 13 · Never turn “no answer” into “yes” — 10:30 · 70s

Never cut this slide.

**Anchor:** “We keep three answers at the gate, not two.”

Say:

> `clean`: the detector ran and found no conflict represented by its model.
>
> `conflicts`: it returned a concrete typed conflict, including the rules that participate.
>
> `unverified`: the detector could not produce a verdict at all — the interpreter is unavailable, the encoder rejected the input, or the command timed out.
>
> A bad answer, a good answer, and no answer are three different things.
>
> This demo fails closed. If the result is unverified, nothing is admitted. That is an application policy, not a magical property of the library, and your activation layer must own that decision explicitly.

Beats: clean → conflicts → unverified, three causes → THE SENTENCE → fails closed, and that's a policy your layer owns.

**Exit:** “…your activation layer must own that decision explicitly.”

### 14 · Every arrow deserves a test — 11:45 · 55s

**Anchor:** “If you remember one engineering warning, remember that the real trust boundary is longer than the Maude command.”

Say:

> Validated Elixir data becomes an encoded term. The term runs in a selected module and interpreter. Text output becomes a typed verdict. The application turns that verdict into an activation decision.
>
> Every arrow deserves a test.
>
> Validate identifiers before encoding. Escape through the encoder rather than interpolating user text. Test that the selected module is the one you think it is. Test the parser. Test `unverified`. Test what deployment does with each state.
>
> Formal reasoning over mistranslated input is still wrong.

Beats: data → term → interpreter → verdict → decision → every arrow → the test list → mistranslated input is still wrong.

**Exit:** “Formal reasoning over mistranslated input is still wrong.”

### 15 · Partition on interaction edges — 12:45 · 55s

**Anchor:** “Does this scale? Not by brute force.”

Say:

> Most rules cannot possibly interact — a dock light in hall three doesn't care about a conveyor in hall nine. But grouping only by device would be unsound, because a cascade crosses devices by definition: one device writes a property that another rule reads.
>
> So we cluster the rules that *could* touch each other, using three conservative edges: same Thing, same action target, and one rule writing a property another one triggers on. Verify each cluster, merge the verdicts. Any unverified cluster makes the whole result unverified.
>
> The dashboard shows the actual rule count, partition count, and skipped pairs. I will read those numbers rather than turn one laptop run into a universal ratio.

Beats: most rules can't touch → device-only grouping is unsound (cascades cross) → three edges → any unverified cluster poisons the merge → read the real numbers.

**Exit:** “…rather than turn one laptop run into a universal ratio.” *(Breathe. Demo time.)*

---

## ACT IV — Live (slides 16–18, ~5:35)

Panel goes full. The LIVE pill drives each beat — press the steps in order, or click the last one to run the chain. Narrate between presses.

### 16 · LIVE 01 — Catch the conflict — 13:45 · 90s

On screen: Rules pane. Steps: **Deploy rule A → Load rule B → Check and create**. Fallback: `mix goatmire.scenario 1`.

**Anchor:** “This is the rule-creation request.”

Say:

> The pair is labelled research-derived on screen: our rule IDs reproduce SOTERIA's O3/O4 contact-open conflict shape.
>
> I’ll deploy the switch-on rule as the existing rule, then load the switch-off rule as the candidate. Now I press “Check and create.”
>
> *(run it — point to the verdict, then the rule ids)*
>
> The gate returns `state_conflict` and names both reproduced rule IDs. Notice what it does not do: it does not guess that safety outranks operations, or that the newer author must be right. It knows the rules disagree, so it refuses the deployment and asks a human to resolve intent.
>
> The conflicting combination never exists in the active set.

Beats: research-derived pair on screen → deploy A, load B, check → `state_conflict`, both IDs named → does NOT guess a winner → never exists in the active set.

**Exit:** “The conflicting combination never exists in the active set.”

### 17 · LIVE 02 — Run the shift twice — 15:15 · 180s

On screen: Warehouse pane, rehearsed fleet size. Steps: **Observe → Enforce**.

**Anchor:** “This floor is a visual sample.”

Say:

> At large fleet sizes it deliberately renders at most five hundred devices so the browser does not become the bottleneck. The engine counters still cover the complete fleet.
>
> First, we run the same shift change in observe mode.
>
> *(run — let the count move, read the displayed result)*
>
> That is the measured output of this simulator, on this machine, at the fleet size and tick rate on screen. It is not a customer incident and not a portable benchmark.
>
> Observe mode records the verdict but deliberately lets known conflicts deploy. It exists to give this controlled comparison — not as a recommended production setting.
>
> Now we reset and run the same staged shift in enforce mode.
>
> *(run — read the withheld rules and alert count)*
>
> The load did not disappear. The broker did not get faster. The difference is that the conflicting pair never reached activation.
>
> The result includes the formal verdict, partitions, pairs considered, pairs skipped, and the counters from this run. The Metrics pane retains the raw series; we will use it only as corroboration after asking the running system directly.

Beats: floor caps at 500, counters cover all → observe: measured output, this machine, not a benchmark → observe exists for the comparison → enforce: same load, same broker → pair never reached activation → verdict + partitions + counters on screen.

**Exit:** “…after asking the running system directly.” *(That sentence IS the bridge to LIVE 03.)*

### 18 · LIVE 03 — Ask the running system why — 18:15 · 65s

On screen: Diagnostics pane. Point at the provider badge BEFORE prompting. Step: **Ask**. If both providers fail: read the structured cards.

**Anchor:** “This page uses our read-only BeamLens skill, not a static dashboard.”

Say:

> The skill supplies a bounded snapshot of the last five minutes: engine rates and alerts, the current Maude verdict and witness, partition work, ExMaude pool health, fleet size, and BEAM runtime pressure.
>
> Let's ask: “Why did alerts rise in the last minute, what formal verdict accompanies this run, and what should I inspect next?”
>
> *(submit — point to cited fields, then the observation/inference split)*
>
> The observations cite structured fields. Inference is labelled separately, with grounding and confidence. You can see in the provider badge whether this answer came from Codex using my existing ChatGPT-plan allowance or the fixed local Ollama fallback — and it shows why a fallback occurred.
>
> No API-key account is accepted, so this demo does not create pay-per-token API charges. Codex still consumes included plan usage. With Ollama, the prompt and snapshot stay on this laptop; with Codex, that bounded diagnostic context goes to the signed-in service.
>
> Most importantly: Maude made the deterministic conflict decision. The language model explained the snapshot. It cannot deploy a rule, operate a device, or turn `conflicts` into `clean`.

Beats: bounded five-minute snapshot → the question, out loud → observations cite fields, inference labelled → provider badge, no API keys → Maude decided, model explained.

**Exit:** “…or turn `conflicts` into `clean`.”

---

## ACT V — The other author (slides 19–22, ~4:40)

Back to split with code cards for 19–21; slide 22 opens Livebook (fallback: Verify pane, Run policy checks).

### 19 · An LLM should not judge itself — 19:20 · 50s

**Anchor:** “Now let's change the policy domain.”

Say:

> An LLM may propose structured automation or agent policy. It should not be the final judge of the policy it just proposed.
>
> This term invokes a dosing tool with a `high_impact` capability in the EU. It contains no explicit approval constructor.
>
> We are not verifying an LLM. We are checking validated structured output produced by one. Different model, same engineering path.

Beats: may propose, not judge → dosing tool, high impact, no approval → not verifying an LLM — checking its validated output.

**Exit:** “Different model, same engineering path.”

### 20 · Exactly seven categories — 20:10 · 50s

**Anchor:** “Here you get exactly seven categories.”

Say:

> Tool-call conflict, capability shadowing, pack/tool composition mismatch, sovereignty violation, authority escalation, approval-gate bypass, and agent-loop cascade.
>
> Exactly seven is more important than an impressive “AI safety” label.
>
> Budget cascade, cost-ceiling feasibility, and provider-routing feasibility are not public detector results here. If the property is not in this list, this detector did not check it.

Beats: the seven (don't recite from memory — they're on the slide, gesture) → exactly seven beats a label → not in the list = not checked.

**Exit:** “If the property is not in this list, this detector did not check it.”

### 21 · A deterministic gate around a probabilistic author — 21:00 · 60s

**Anchor:** “The loop is simple.”

Say:

> We generate structured rules, validate and encode them, return a typed conflict, feed that conflict into a revision, and verify again.
>
> If no language model is reachable on stage, we keep that failure visible and skip the authoring beat. The deterministic policy check on the next slide still demonstrates the gate without pretending a canned response was live.
>
> The valuable boundary is not “AI versus no AI.” It is probabilistic author, deterministic policy gate.

Beats: generate → validate → typed conflict → revise → verify again → visible failure, skip the beat honestly → author vs gate.

**Exit:** “…probabilistic author, deterministic policy gate.”

### 22 · LIVE 04 — The policy by hand — 22:00 · 120s

On screen: Livebook Scenario 5 (fallback: Verify pane, Run policy checks).

**Anchor:** “Nothing moves in this notebook.”

Say:

> No fleet, no broker, no language model, no network. That makes it the recovery path for the entire talk.
>
> First: high impact, no approval.
>
> *(run — read `approval_gate_bypass`)*
>
> Now we add an explicit approval constructor before the invocation.
>
> *(run — read the empty list and immediately narrow it)*
>
> This detector found none of its seven modelled conflicts.
>
> Finally, I route an invocation to the US while the allowed set is EU and Switzerland.
>
> *(run — read `sovereignty_violation`)*
>
> And this final cell shows the raw Maude command generated by the real encoder. It is not a hand-copied command made to look convincing. Documentation that imitates an encoder will drift; generated evidence stays attached to the term we just read.

Beats: nothing moves — recovery path → no approval: bypass → add approval: empty, narrow it immediately → US under EU/CH: sovereignty → the raw command is generated, not hand-copied.

**Exit:** “…generated evidence stays attached to the term we just read.”

---

## ACT VI — Choose and close (slides 23–25, ~7:05 incl. reserve)

Split view, Metrics pane ambient. Slide 25 is your 5-minute reserve: links, questions, other projects.

### 23 · Maude is not the only answer — 24:00 · 60s

**Anchor:** “So why Maude — why not TLA+?”

Say:

> Choose a formal tool by the shape of the property. Maude is a natural fit for algebraic terms and concurrent transitions — which is what automation rules are.
>
> TLA+ is often a better fit for temporal behaviours in distributed systems. Alloy is excellent for bounded relational structures. An SMT solver such as Z3 is powerful for constraints and satisfiability. Types and protocol-specific model checkers may give a clearer answer elsewhere.
>
> Tool loyalty is not a verification strategy. Choose the model that makes the property clearest and the translation easiest to distrust constructively.

Beats: choose by property shape → the table is on the slide, gesture, don't recite → tool loyalty is not a strategy.

**Exit:** “…easiest to distrust constructively.”

### 24 · Keep the claim attached to its evidence — 25:10 · 65s

**Anchor:** “Before you take this pattern toward production, do the unglamorous work.”

Say:

> Validate input. Test every translation edge. Bound pool size, checkout time, command time, and search depth. Restart a worker after timeout because its interpreter state may be uncertain. Keep independent consumers in independent named pools.
>
> For an audit artifact, record the model revision, interpreter version, validated input, typed result, duration, and activation decision.
>
> That artifact can be valuable engineering evidence. It does not automatically satisfy a regulation; that needs a separate control mapping.

Beats: validate, test edges, bound everything, restart after timeout → the audit artifact list → evidence yes, regulation no.

**Exit:** “…that needs a separate control mapping.”

### 25 · Close — 26:25 · 5:00 reserve

**Anchor:** “The library, demo, Docker stack, notebooks, and this deck are open if you want to try the pattern.”

Say:

> I want you to take away three things.
>
> First: inspect rule composition before activation, because reasonable local decisions can create an unreasonable system.
>
> Second: preserve all three answers — clean, conflicts, and unverified. Never turn “I could not check” into “yes.”
>
> Third: verify the same term the runtime executes, and test every translation edge around it.
>
> Formal methods make a narrow claim strong. They do not make a broad claim true.
>
> Thank you.

Do: stop. Do not add a second ending. The remaining reserve is for links, questions, and whatever you feel like showing.

Beats: three takeaways: composition before activation → three answers, never “could not check” into “yes” → same term, every edge → THE LINE → thank you, stop.
