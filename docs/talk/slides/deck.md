---
marp: true
theme: goatmire-livebook
size: 16:9
paginate: true
html: true
title: Zero Alert Storms
description: Formal Verification for IoT Automation — Goatmire 2026
author: Tobias Bohwalli
---

<!-- _class: title -->
<!-- _paginate: false -->
<!-- _footer: "" -->

<div class="eyebrow">Goatmire 2026 · 30 minutes</div>

# Zero Alert Storms

<p class="lede">Formal verification for IoT automation—at the deployment gate, before reasonable rules become an unreasonable system.</p>

**Tobias Bohwalli**

<!--
Pause. Let the room read the title. Promise one thing: we will create a storm,
then stop the same storm before either rule can run.

[Sources]
- No external claim on this slide.
[/Sources]
-->

---

<div class="eyebrow">A published interaction</div>

# Both apps were reasonable

<div class="huge">O3 + O4</div>

<p class="lede">the same contact-open event sets one switch to conflicting values.</p>

<!--
SOTERIA reports this conflict shape in its multi-app evaluation. This repo
reproduces the rule shape; it is not a household incident or prevention claim.

[Sources]
- SOTERIA: https://www.usenix.org/system/files/conference/atc18/atc18-celik.pdf
[/Sources]
-->

---

<div class="eyebrow">One event · one switch · two values</div>

# Both rules are reasonable

<div class="two">
  <div class="panel">
    <div class="label">SOTERIA O3 shape</div>
    <h2>Contact opens</h2>
    <p>Set <code>switch</code> to <code>on</code>.</p>
  </div>
  <div class="panel">
    <div class="label">SOTERIA O4 shape</div>
    <h2>Contact opens</h2>
    <p>Set <code>switch</code> to <code>off</code>.</p>
  </div>
</div>

<!--
Each automation can pass an isolated review. The disagreement exists only when
the installed rule set is composed.

[Sources]
- Research reproduction: `Goatmire.Rules.research_state_conflict_pair/0`.
- SOTERIA: https://www.usenix.org/system/files/conference/atc18/atc18-celik.pdf
[/Sources]
-->

---

<div class="eyebrow">Composition is the bug</div>

# The loop nobody designed

<div class="flow">
  <div class="node">contact open</div><div class="arrow">→</div>
  <div class="node">O3: on</div><div class="arrow">↔</div>
  <div class="node">same switch</div><div class="arrow">↔</div>
  <div class="node">O4: off</div>
</div>

<blockquote>Every component can work while the system is absurd.</blockquote>

<!--
The published example establishes the interaction pattern. Our simulator later
shows how repeatedly activating a synthetic conflicting set can amplify alerts.

[Sources]
- SOTERIA and repository research reproduction.
[/Sources]
-->

---

<div class="eyebrow">The deployment question</div>

<div class="statement">If the relationship exists before activation, why wait for telemetry to discover it?</div>

<!--
This is the turn. We are not replacing runtime monitoring. We are moving one
class of discovery earlier, into the rule-creation request.

[Sources]
- No external claim on this slide.
[/Sources]
-->

---

<div class="eyebrow">Testing and formal checking answer different questions</div>

# Sample behaviour—or decide an encoded predicate

<div class="two">
  <div class="panel">
    <div class="label">tests / simulation</div>
    <div class="value">Did these executions fail?</div>
    <p class="small">Excellent for runtime code, timing, integration, and properties over generated cases.</p>
  </div>
  <div class="panel">
    <div class="label">equational detector</div>
    <div class="value">Does this finite term match the conflict definition?</div>
    <p class="small">Strong only inside the validated input and encoded model.</p>
  </div>
</div>

<!--
Do not say “testing is probabilistic” as a blanket statement. Tests can be
exhaustive over a finite domain too. The point is that these tools support
different claims.

[Sources]
- Maude manual: https://maude.cs.illinois.edu/wiki/The_Maude_System
[/Sources]
-->

---

<div class="eyebrow">A Maude mental model</div>

# Four pieces

<div class="four">
  <div class="panel"><div class="label">sorts</div><div class="value">types</div></div>
  <div class="panel"><div class="label">operators</div><div class="value">constructors + functions</div></div>
  <div class="panel"><div class="label">equations</div><div class="value">simplify</div></div>
  <div class="panel"><div class="label">rewrite rules</div><div class="value">transition</div></div>
</div>

<p class="lede" style="margin-top:34px">For an Elixir developer: complete function clauses versus possible state transitions.</p>

<!--
Keep this deliberately small. The audience needs enough vocabulary to read the
next command, not a rewriting-logic lecture.

[Sources]
- Maude manual: https://maude.cs.illinois.edu/wiki/The_Maude_System
[/Sources]
-->

---

<div class="eyebrow">Two commands · two claims</div>

# Reduce is not search

```text
reduce in SWITCH : toggle(toggle(on)) .

search [1] in CELL : idle =>* ready .
```

<div class="two" style="margin-top:24px">
  <p><strong>reduce</strong><br><span class="small">normal form under equations</span></p>
  <p><strong>search</strong><br><span class="small">reachable witness under transitions</span></p>
</div>

<!--
A returned search result is a concrete reachable witness. No witness inside a
bound is not an unbounded proof. ExMaude reports clean bounded safety/liveness
searches as unverified.

[Sources]
- ExMaude API and notebooks: https://github.com/futhr/ex_maude
- Maude manual: https://maude.cs.illinois.edu/wiki/The_Maude_System
[/Sources]
-->

---

<div class="eyebrow">The bundled IoT model</div>

# Four conflict categories

<div class="two">
  <div class="panel"><h2>state conflict</h2><p class="small">same action target + property, incompatible writes</p></div>
  <div class="panel"><h2>environment conflict</h2><p class="small">actions push a shared environmental property apart</p></div>
  <div class="panel"><h2>state cascade</h2><p class="small">one action satisfies another rule's trigger</p></div>
  <div class="panel"><h2>state–environment cascade</h2><p class="small">the causal chain crosses state and environment</p></div>
</div>

<!--
This is a smaller custom model inspired by published conflict categories, not
an implementation of a complete external system.

[Sources]
- ExMaude model: `priv/maude/iot-rules.maude` in https://github.com/futhr/ex_maude
[/Sources]
-->

---

<div class="eyebrow">Formal methods need a border</div>

# A narrow claim can be strong

<div class="two">
  <div class="panel clean">
    <h2>Inside</h2>
    <p>validated finite rules<br>encoder<br>selected model<br>interpreter result</p>
  </div>
  <div class="panel">
    <h2>Outside</h2>
    <p>physics · firmware timing · authorization · omitted hazards · deployment reality</p>
  </div>
</div>

<!--
No model boundary, no honest formal claim. A clean result does not mean the
system is safe in every respect.

[Sources]
- Repository study guide: `docs/maude-for-dummies.md`.
[/Sources]
-->

---

<div class="eyebrow">ExMaude</div>

# Maude as an ordinary supervised dependency

<div class="flow">
  <div class="node">Elixir caller</div><div class="arrow">→</div>
  <div class="node">named worker pool</div><div class="arrow">→</div>
  <div class="node">Maude subprocess</div><div class="arrow">→</div>
  <div class="node">typed result</div>
</div>

```elixir
ExMaude.IoT.detect_conflicts(rules)
```

<!--
The application owns the pool in its supervision tree. The default port
backend talks to a separate Maude process over pipes. Other backends exist, but
this talk makes no universal latency ranking.

[Sources]
- ExMaude README and API: https://github.com/futhr/ex_maude
[/Sources]
-->

---

<div class="eyebrow">One representation · two consumers</div>

# Verify the term the runtime executes

<div class="branch-source">%{trigger: …, actions: …}</div>
<div class="branch-arrow">↙ &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; ↘</div>
<div class="two">
  <div class="panel" style="text-align:center;font-weight:650">ExMaude encoder + detector</div>
  <div class="panel" style="text-align:center;font-weight:650">rule evaluator + actuator</div>
</div>

<blockquote>A verified copy that drifts from runtime proves the wrong thing precisely.</blockquote>

<!--
This is the implementation detail worth remembering. Goatmire.Rules produces
the maps, ExMaude.IoT encodes them, and Goatmire.Engine.RuleEval executes them.

[Sources]
- Repository modules: `Goatmire.Rules`, `Goatmire.Verifier`, `Goatmire.Engine.RuleEval`.
[/Sources]
-->

---

<div class="eyebrow">The gate has three answers</div>

# Never turn “no answer” into “yes”

<div class="three">
  <div class="verdict clean"><strong>clean</strong><span>detector ran; no modelled conflict found</span></div>
  <div class="verdict conflicts"><strong>conflicts</strong><span>concrete typed conflict + rule ids</span></div>
  <div class="verdict unverified"><strong>unverified</strong><span>timeout, unavailable backend, or rejected input</span></div>
</div>

<!--
This is the spine of the talk. A bad answer, a good answer, and no answer are
three different things. Goatmire fails closed on unverified.

[Sources]
- Repository module: `Goatmire.Verifier`.
[/Sources]
-->

---

<div class="eyebrow">The real trust boundary</div>

# Every arrow deserves a test

<div class="flow">
  <div class="node">validated Elixir data</div><div class="arrow">→</div>
  <div class="node">encoder</div><div class="arrow">→</div>
  <div class="node">Maude term + module</div><div class="arrow">→</div>
  <div class="node">parsed verdict</div><div class="arrow">→</div>
  <div class="node">activation policy</div>
</div>

<!--
Formal reasoning over a mistranslated input is still wrong. Validate identifiers,
escape via the encoder, test the selected module, and keep deployment policy in
the application.

[Sources]
- Repository study guide: `docs/maude-for-dummies.md`.
[/Sources]
-->

---

<div class="eyebrow">Scale the comparison, not the claim</div>

# Partition on interaction edges

<div class="two">
  <div class="panel">
    <div class="label">conservative edges</div>
    <div class="value">same Thing</div>
    <div class="value">same action target</div>
    <div class="value">writer → trigger property</div>
  </div>
  <div class="panel">
    <div class="label">on screen</div>
    <div class="value">rules</div>
    <div class="value">partitions</div>
    <div class="value">pairs skipped</div>
  </div>
</div>

<p class="lede" style="margin-top:30px">Grouping only by Thing would miss cross-Thing cascades.</p>

<!--
Read the actual numbers from the dashboard or notebook. Do not memorize a
ratio. The partitioner deliberately over-groups when model internals are
uncertain.

[Sources]
- Repository module: `Goatmire.Rules.partition/1`.
[/Sources]
-->

---

<!-- _class: demo -->
<!-- _paginate: false -->
<!-- _footer: "" -->

<div>
  <p>LIVE · 01</p>
  <h1>Catch the conflict before the rule exists</h1>
  <p>localhost:4000/rules/new</p>
</div>

<!--
Seed rule A. Load rule B. Check and create. Read the typed conflict and both
rule ids. Do not deploy. If the page fails, run `mix goatmire.scenario 1`.

[Sources]
- Repository LiveView: `GoatmireWeb.RuleLive`.
[/Sources]
-->

---

<!-- _class: demo -->
<!-- _paginate: false -->
<!-- _footer: "" -->

<div>
  <p>LIVE · 02</p>
  <h1>Run the same shift change twice</h1>
  <p>observe → enforce · read the measured counters</p>
</div>

<!--
Use a rehearsed fleet size. Run observe, then enforce. Read the
alerts, withheld rules, and throttled counters from this machine. Never call it
a customer incident or a portable benchmark.

[Sources]
- Repository scenario: `Goatmire.Scenario.Storm`.
[/Sources]
-->

---

<!-- _class: demo -->
<!-- _paginate: false -->
<!-- _footer: "" -->

<div>
  <p>LIVE · 03</p>
  <h1>Ask the running system why</h1>
  <p>BeamLens · bounded snapshot · cited fields · visible provider</p>
</div>

<!--
Ask why alerts rose, which formal verdict accompanies the run, and what to
inspect next. Point to observations versus inference, grounding, metric fields,
and the Codex/Ollama provider badge. Maude decided; the model explained.

[Sources]
- Repository LiveView: `GoatmireWeb.DiagnosticsLive`.
- BeamLens skill: `Goatmire.Diagnostics.Skill`.
[/Sources]
-->

---

<div class="eyebrow">The pattern transfers</div>

# An LLM may propose policy; it should not judge itself

```elixir
invocations: [
  {:invoke_tool, "dose", %{}, "high_impact", :eu}
]
```

<p class="lede">Structured output in. Deterministic policy equations out.</p>

<!--
This does not verify an LLM. It checks validated structured output produced by
one. Different model, identical trust boundary.

[Sources]
- ExMaude AI API: https://github.com/futhr/ex_maude
[/Sources]
-->

---

<div class="eyebrow">The bundled AI policy model</div>

# Exactly seven categories

<div class="two">
  <div class="panel"><p>tool-call conflict<br>capability shadowing<br>pack/tool mismatch<br>sovereignty violation</p></div>
  <div class="panel"><p>authority escalation<br>approval-gate bypass<br>agent-loop cascade</p></div>
</div>

<blockquote>If it is not in this list, this detector did not check it.</blockquote>

<!--
Do not add budget, cost-ceiling, or provider-routing claims. They are not public
detector results in the current code.

[Sources]
- ExMaude model: `priv/maude/ai-rules.maude` in https://github.com/futhr/ex_maude
[/Sources]
-->

---

<div class="eyebrow">Generate · verify · revise</div>

# Put a deterministic gate around a probabilistic author

<div class="flow">
  <div class="node">generate structured rules</div><div class="arrow">→</div>
  <div class="node">validate + encode</div><div class="arrow">→</div>
  <div class="node">typed conflict</div><div class="arrow">→</div>
  <div class="node">revise</div><div class="arrow">↺</div>
</div>

<!--
If the configured model is unreachable, show the failure and continue to the
deterministic policy check.

[Sources]
- Repository module: `Goatmire.AI.RuleGenerator`.
[/Sources]
-->

---

<!-- _class: demo -->
<!-- _paginate: false -->
<!-- _footer: "" -->

<div>
  <p>LIVE · 04</p>
  <h1>Approval missing → clean revision → wrong jurisdiction</h1>
  <p>Livebook · generated command, not a hand-copied command</p>
</div>

<!--
Open Scenario 5. Run the three exact outcomes: approval_gate_bypass, empty,
sovereignty_violation. Show the command from the real encoder. This is the
offline fallback for the whole talk.

[Sources]
- Repository module: `Goatmire.VerificationDemo`.
[/Sources]
-->

---

<div class="eyebrow">Choose by property shape</div>

# Maude is not the only answer

| Need | Reach for |
|---|---|
| algebraic terms + concurrent transitions | Maude |
| temporal distributed behaviours | TLA+ / PlusCal |
| bounded relational structures | Alloy |
| constraints and satisfiability | SMT / Z3 |
| protocol/session conformance | types, model checking, or both |

<!--
Choose the model that makes the property clearest. Tool loyalty is not a
verification strategy.

[Sources]
- TLA+: https://lamport.azurewebsites.net/tla/tla.html
- Alloy: https://alloytools.org/
- Z3: https://github.com/Z3Prover/z3
[/Sources]
-->

---

<div class="eyebrow">Before production</div>

# Keep the claim attached to its evidence

<div class="two">
  <div class="panel">
    <h2>Engineering</h2>
    <p>validate input<br>test every translation edge<br>bound time + pool + search<br>restart uncertain workers</p>
  </div>
  <div class="panel">
    <h2>Audit</h2>
    <p>model revision<br>interpreter version<br>validated term<br>typed result<br>activation decision</p>
  </div>
</div>

<!--
An audit artifact does not automatically satisfy a regulation. A timeout stays
an error or unverified. The activation layer owns fail-open/fail-closed policy.

[Sources]
- Repository study guide: `docs/maude-for-dummies.md`.
[/Sources]
-->

---

<!-- _class: closing -->
<!-- _paginate: false -->
<!-- _footer: "" -->

<div>
  <blockquote>Formal methods make a narrow claim strong. They do not make a broad claim true.</blockquote>
  <p class="small mono">github.com/futhr/ex_maude · github.com/futhr/goatmire-2026</p>
</div>

<!--
Three takeaways: inspect composition before activation; preserve clean,
conflicts, and unverified; verify the same term the runtime executes. Thank the
room and stop.

[Sources]
- ExMaude: https://github.com/futhr/ex_maude
- Demo: https://github.com/futhr/goatmire-2026
[/Sources]
-->
