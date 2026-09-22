# Maude, ExMaude, and the Goatmire Demo

This is the technical study guide behind “Zero Alert Storms: Formal Verification for IoT Automation.” It describes the code that exists in the local `ex_maude` and `goatmire-2026` repositories as of 19 August 2026. When this guide and the code disagree, the code and its tests win.

It is also the talk's dictionary. If a word from the speech is hard to explain in one breath, [section 15](#15-talk-dictionary) explains it in plain terms, in the order the talk uses it. [Section 16](#16-jev-and-maude--same-slot-different-contract) covers the Jev comparison and why the two decision models can coexist.

Local library changes may be unreleased even when their version strings match Hex. The application installs locked Hex ExMaude by default; see [dependency maintenance](dependencies.md) for how that resolution works.

## 1. The useful mental model

Why would an Elixir developer care about a term rewriter from the formal-methods world? Because Maude can *decide* things about your automation rules that tests can only *sample* — and it turns out you already know most of its ideas under different names.

Maude describes a system with four pieces, and each one has an Elixir cousin.

A **sort** is a type — think `@type state :: :on | :off`. An **operator** builds or transforms terms, like constructors and functions. An **equation** simplifies a term the way pattern-matched function clauses do: keep applying until nothing changes. A **rewrite rule** is different — it says “from this state, that state can happen next.” A transition, not a computation.

You only need two commands:

```text
reduce in MODULE : term .
search [1] in MODULE : initial =>* pattern .
```

`reduce` runs the equations until the term settles. Deterministic, like calling a pure function. `search` walks the rewrite rules looking for a reachable state — like exploring a state machine for a bad configuration.

They answer different questions, and this distinction carries the whole talk. `reduce` *decides*: given these rules, conflict or no conflict — and it can genuinely decide, yes or no, because the detector's equations cover every case of a finite, validated input. Same reason an exhaustive `case` over a closed enum can't miss a branch. `search` *finds witnesses*: an actual path to the bad state.

An empty bounded search establishes only that no witness was found within that bound; it does not by itself establish unbounded safety. Raw `ExMaude.search/4` returns `{:ok, []}`. The higher-level bounded IoT safety and liveness helpers translate no witness into `{:ok, :unverified}`.

One more boundary to keep in your head the whole way through: “no modeled conflict found” does not mean “the system is safe in every respect.” It means the conflicts this model knows about aren't in the rules you handed it.

## 2. Small Maude example

Here's a complete Maude module. Read it before the explanation:

```maude
fmod SWITCH is
  sort State .
  ops on off : -> State [ctor] .
  op toggle : State -> State .

  eq toggle(on) = off .
  eq toggle(off) = on .
endfm
```

One sort (`State`), two constructors (`on`, `off`), one function (`toggle`), and two equations that say what `toggle` does. Then:

```text
reduce in SWITCH : toggle(toggle(on)) .
```

returns `on`. The interpreter applied the equations until the term couldn't simplify further — exactly like Elixir applying pattern-matching function clauses until it has a final value.

Rewrite rules use `rl` or `crl` and express transitions rather than equalities. Search explores their possible interleavings, which is useful for state machines and cascade witnesses — but its cost and its conclusion depend on the model, the branching factor, the search form, and the depth you gave it.

## 3. What ExMaude is

First question a senior asks: is this a NIF? What owns the process?

ExMaude is an Elixir library that supervises Maude subprocesses — the interpreter runs outside the BEAM, and your supervision tree owns the workers the same way it owns a database pool. The public surface:

```elixir
ExMaude.reduce(module, term, opts \\ [])
ExMaude.rewrite(module, term, opts \\ [])
ExMaude.search(module, initial, pattern, opts \\ [])
ExMaude.load_file(path, opts \\ [])
ExMaude.load_module(source, opts \\ [])
ExMaude.execute(command, opts \\ [])
ExMaude.version()
```

It starts no pool automatically — the consumer puts one in its own tree:

```elixir
children = [
  ExMaude.Pool.child_spec(
    name: :ex_maude_pool,
    pool_size: 1,
    pool_max_overflow: 0
  )
]
```

That one-worker configuration is the smallest useful consumer example. This talk application starts four workers so the dashboard and rehearsal tools can issue independent reductions without waiting on each other.

Pools are named, and each pool keeps its own loaded modules and preloads. Two independent consumers can't contaminate each other's Maude sessions.

## 4. Installing Maude

What are you actually installing, license-wise? ExMaude 0.4 is an MIT-licensed Hex package. The Maude interpreter itself is GPL-licensed and is **not** bundled — you install it separately.

```elixir
{:ex_maude, "~> 0.4"}
```

```bash
mix deps.get
mix maude.install
```

Alternatively, keep a compatible `maude` on `PATH` or configure:

```elixir
config :ex_maude, maude_path: "/absolute/path/to/maude"
```

The ExMaude Git checkout contains development binaries for selected hosts, but that is not the Hex-package contract. On stage, show `ExMaude.version/0` from the actual rehearsal machine instead of promising a version in the script.

## 5. Backends

Which backend is fastest? Wrong first question — pick by blast radius, then measure.

- **Port**: the default. A separate Maude process over plain pipes. PTY mode is opt-in. If Maude dies, the BEAM doesn't notice beyond a restarted worker.
- **C-Node**: a separate C bridge process speaking Erlang Distribution.
- **NIF**: a Rustler extension that manages a Maude subprocess. The Maude child is still a separate process, but native code now lives inside the BEAM — a crash there can take the whole VM.

There is no justified universal latency ranking in this repo. Choose with a reproducible workload and the operational requirements you actually have. Source-building the NIF is explicit:

```bash
EX_MAUDE_BUILD=1 mix deps.compile ex_maude
```

A local ignored NIF artifact must not force Rustler onto a path-based consumer.

## 6. IoT conflict model

What can it actually catch? Four things, and it's honest about the list.

`ExMaude.IoT.detect_conflicts/2` targets `priv/maude/iot-rules.maude`, currently 522 lines. The schema is inspired by the conflict categories discussed by AutoIoT, but it is a smaller custom model — not an implementation of that full system.

The four modeled categories:

1. **State conflict** — two rules write incompatible values to the same device property. The O3/O4 case.
2. **Environment conflict** — two actions push a shared environmental property in opposite directions.
3. **State cascade** — one rule's action satisfies another rule's trigger. A chain reaction.
4. **State–environment cascade** — the same chain, crossing between device state and the environment.

An empty list means one thing: these four conflicts aren't in the validated rules you handed it. It says nothing about physical hazards, timing requirements, runtime authorization, or deployment conditions — the model doesn't encode those, so the detector can't see them.

ExMaude also exposes bounded IoT safety and liveness helpers. A counterexample is a meaningful witness. Exhausting the bound without one returns `:unverified` — the search gave up before finding trouble, and that is never relabelled `:safe` or `:live`.

## 7. AI policy conflict model

Can it check agent policies too? Yes — same mechanism, different model.

`ExMaude.AI.detect_conflicts/2` targets `priv/maude/ai-rules.maude`, currently 733 lines. It implements exactly seven conflict types:

1. `:tool_call_conflict`
2. `:capability_shadowing`
3. `:pack_tool_composition_mismatch`
4. `:sovereignty_violation`
5. `:authority_escalation`
6. `:approval_gate_bypass`
7. `:agent_loop_cascade`

Exactly seven matters more than an impressive label. There is no `ExMaude.AI.verify_property/2`. Budget-cascade, cost-ceiling-infeasibility, and provider-routing-infeasibility are not public detector results and must not appear as implemented talk features. If a property isn't in the list, this detector did not check it.

Here's the shape of a policy and what the detector says about it:

```elixir
policy = [
  %{
    id: "autodose-controller",
    agent_id: {"acme", "controller"},
    trigger: {:always},
    invocations: [
      {:invoke_tool, "dose", %{}, "high_impact", :eu}
    ]
  }
]

{:ok, conflicts} =
  ExMaude.AI.detect_conflicts(policy, jurisdictions: [:eu])

Enum.map(conflicts, & &1.type)
# => [:approval_gate_bypass]
```

The policy reaches a high-impact tool with no approval step in the chain, so the detector flags it. Add the approval constructor before the invocation and that particular finding goes away:

```elixir
invocations: [
  {:require_approval, "dosing_high_delta"},
  {:invoke_tool, "dose", %{}, "high_impact", :eu}
]
```

The supported conclusion after that fix is not “the policy is safe.” It is: the detector found none of its seven modeled conflicts. Narrow, and defensible.

## 8. Generate, do not imitate, the Maude command

How do you know the Maude term actually matches your Elixir data? By never hand-writing it.

The talk's Scenario 5 uses the real encoder:

```elixir
{:ok, encoded_policy} = ExMaude.AI.Encoder.encode_rules(policy)
jurisdictions = ExMaude.AI.Encoder.encode_jurisdiction_set([:eu])

command =
  "reduce in AI-CONFLICT-DETECTOR : " <>
    "detectAllConflicts(#{encoded_policy}, #{jurisdictions}) ."

{:ok, output} = ExMaude.execute(command)
```

This avoids a common documentation failure: a hand-written “raw command” that slowly drifts away from what the encoder really produces.

The trust boundary is a chain, and it's longer than the Maude command in the middle:

```text
validated Elixir data
  → encoder
  → generated Maude term
  → selected module and interpreter
  → parsed typed result
  → caller's activation policy
```

Every arrow deserves tests. Formal reasoning over a mistranslated input proves the wrong model — precisely.

## 9. How the demo consumes the results

What happens when Maude is down mid-deploy? That's the question this section answers, and the answer is the talk's spine.

`Goatmire.Verifier` keeps three outcomes apart and never merges them:

- `:conflicts` — a concrete typed conflict, with the rule ids.
- `:clean` — no conflict of the types this detector models.
- `:unverified` — the application did not obtain a usable, complete detector verdict.

Skipped checks, unavailable backends, and encoder rejections land in `:unverified`. The bounded IoT helpers also use that status when no witness is found; Goatmire's deployment gate uses the equational conflict detector, not those search helpers. None of these uncertain outcomes becomes a success claim. A bad answer, a good answer, and no answer are three different things.

`split_on_verdict/2` fails closed: an unverified rule set admits nothing. And when a conflict names two rules, it withholds *both* of them rather than guessing which author was right.

Fail-open versus fail-closed is the activation layer's decision to own, not the library's. A library availability error is not evidence that input is safe — this demo takes the conservative side of that choice explicitly rather than by default.

## 10. The five demos

Everything runs from this repository. Scenarios 1, 3 and 5 need only the interpreter. Scenario 2 additionally boots the fleet and the engine. Scenario 4 additionally needs the configured language model to be reachable; otherwise skip it and continue with deterministic Scenario 5.

The entire stage fleet is simulated, and the storm counters are this machine's measured output — not customer incidents and not physical-fleet evidence.

Scenario 5 is the one that depends on nothing but the interpreter:

```elixir
Goatmire.VerificationDemo.run()
```

It asserts three exact outcomes:

- missing approval → `[:approval_gate_bypass]`
- explicit approval → `[]`
- US invocation under EU/CH allowance → `[:sovereignty_violation]`

The application starts a four-worker ExMaude pool, and tests reject any drift in these results — a library change that quietly alters a verdict is caught in rehearsal rather than on stage.

## 11. Performance claims

How fast is it? Refuse to answer that from memory.

Do not memorize `500 µs`, `600 ms`, an 80% pre-filter ratio, or a scale number. None is a portable property of Maude or ExMaude. On stage, read the displayed measurement from the final rehearsal build.

A defensible benchmark records:

- repository revisions
- Maude and OTP versions
- backend and pool settings
- host OS/architecture
- exact rule corpus and search bounds
- cold versus warm execution
- sample count and reported distribution
- timeouts and errors

A timeout remains an error or `:unverified` — it never becomes a data point for the happy path.

## 12. Security and operational boundaries

What would you have to care about before running this anywhere near production?

- Validate identifiers and predicates before encoding them.
- Never create atoms from untrusted strings.
- Escape strings through the library encoder; do not interpolate raw user input into Maude commands.
- Keep command text out of telemetry unless explicitly enabled and safe.
- Treat module sources and file paths as trusted administrative input.
- Bound pool size, checkout time, command time, and search depth.
- Restart workers after a timeout — their interpreter state is uncertain.
- Keep independently named pools isolated.
- Record model revision, interpreter version, validated input, and result when building an audit artifact.
- Do not claim such an artifact satisfies a regulation without a separate documented control mapping.

## 13. Honest Q&A answers

**Does ExMaude prove my application correct?**

No. It evaluates properties of the encoded model. Encoder correctness, omitted properties, runtime behavior, and the deployment environment stay outside that result.

**What does an empty conflict list mean?**

That this detector found none of the conflicts it models, in this input. Nothing more.

**What does a bounded search prove?**

A returned counterexample is reachable in the model — that's real. An empty result within the bound means the search gave up before finding trouble, and it's reported as unverified, not as a proof.

**Can it verify an LLM?**

No. It can inspect validated structured output that an LLM produced. The model authors; the detector judges.

**Does it run on constrained edge hardware?**

This talk doesn't demonstrate that. Maude and the simulated fleet run on the demo laptop and support containers. Validate a compatible interpreter and benchmark before making any edge-host claim.

**Is anyone running this in production?**

Not that the speaker can point at, and the talk says so. What exists is a public MIT library, its test suite, and this demo repository: real code, a real broker, real reductions — and still a demo.

## 14. Rehearsal checklist

1. Run the unit suite.
2. Run `mix goatmire.scenario 5` from a cold application start.
3. Confirm `ExMaude.version/0` displays the expected installed interpreter.
4. Run the Scenario 5 Livebook top to bottom.
5. Inspect the generated command, not a hand-copied command.
6. Exercise Scenarios 1–4 on the actual demo laptop, including the unverified path (rename the `maude` binary and confirm the UI says so).
7. Save benchmark metadata before adding a number to a slide.
8. If Maude is unavailable, say “unverified.” If the model is unavailable, show the provider failure and skip the generation beat.

The memorable line is:

> Formal methods strengthen narrow claims. They cannot prove broad ones.

## 15. Talk dictionary

These are the harder words the speech uses, in the order it uses them. Each entry says what the thing is, gives you an Elixir handle on it, and names the slide where it comes up. The entries were checked against the code on 18 September 2026.

### SOTERIA

SOTERIA is a published research system from USENIX ATC 2018. It reads the source code of SmartThings smart-home apps, builds a state model from it, and checks that model against safety and security properties.

Its multi-app evaluation looks at what happens when several apps are installed together. That's where the talk's example comes from.

SOTERIA did not use Maude, and this repo does not implement SOTERIA. The demo reproduces one rule shape from the paper inside ExMaude's smaller IoT model. The paper motivates the problem; it does not validate this code.

On stage: slide 2. Source: [the paper](https://www.usenix.org/conference/atc18/presentation/celik).

### O3 and O4, and conflicting writes

O3 and O4 are two apps from SOTERIA's multi-app evaluation. Both react to the same event, a contact sensor opening. O3 turns a switch on. O4 turns the same switch off.

Here is the repo's reproduction, from `Goatmire.Rules.research_state_conflict_pair/0`:

```elixir
%{id: "soteria-o3-contact-open-turn-on", thing_id: "smart-switch-1",
  trigger: {:prop_eq, "contact", "open"},
  actions: [{:set_prop, "smart-switch-1", "switch", "on"}], priority: 1}

%{id: "soteria-o4-contact-open-turn-off", thing_id: "smart-switch-1",
  trigger: {:prop_eq, "contact", "open"},
  actions: [{:set_prop, "smart-switch-1", "switch", "off"}], priority: 1}
```

A conflicting write is exactly this: two rules that can fire together write different values to the same property of the same device. Think of two processes both calling `Agent.update/2` on one key with opposite values. Each call is fine. Together, the final value depends on who runs last.

The O3/O4 pair shows conflicting writes. It does not show an alert loop by itself. The loop comes later, from the synthetic set.

On stage: slides 2–4 and the LIVE 01 demo on slide 16.

### Synthetic conflicting set and the alert storm

The synthetic conflicting set is a rule set the repo invented to make the conflict noisy. It is not from any paper and not from any customer.

`Goatmire.Rules.fleet/1` gives every simulated AGV (a warehouse robot) two rules:

```elixir
%{id: "agv-1-low-battery-route", trigger: {:prop_lt, "battery", 20},
  actions: [{:set_prop, "agv-1", "destination", "dock-7"}]}

%{id: "agv-1-zone7-day-shift", trigger: {:prop_gte, "hour", 9},
  actions: [{:set_prop, "agv-1", "destination", "dock-19"}]}
```

Each rule is sensible on its own. A robot with a low battery should go to the charging dock. A robot on the day shift should go to Zone 7.

The storm scenario stages a shift change: the clock passes 09:00 and a batch of robots drops below 20% battery. Now both rules fire on every telemetry tick, and each robot's `destination` keeps flipping between `dock-7` and `dock-19`.

The engine raises an alert whenever a property actually changes, not when a value is re-asserted. So every flip is an alert, and a fleet of flipping robots makes an alert storm.

On stage: slide 4 and the LIVE 02 demo on slide 17.

### Observe mode and enforce mode

These are the two ways the storm demo deploys the same rule set.

In observe mode, the checker runs and records its verdict, but every rule is deployed anyway. You see the symptom: the alert counter climbs.

In enforce mode, the checker runs and the gate withholds every rule named in a conflict. Both rules of a pair are held back, because the gate doesn't guess which author was right. The alert counter stays quiet.

Same fleet size, same tick rate, same shift change. Scheduling and random readings still differ between runs, so the two runs are a like-for-like comparison, not an exact replay.

On stage: slide 17.

### Sort

A sort is a type. Read `sort State .` like `@type state :: ...`.

On stage: slide 7. See the `SWITCH` module in [section 2](#2-small-maude-example).

### Operator

An operator builds a value or computes one. `ops on off : -> State [ctor] .` declares two constructors, like the atoms `:on` and `:off`. `op toggle : State -> State .` declares a function from state to state.

On stage: slide 7.

### Equation

An equation says two terms are equal, and Maude uses it left to right to simplify. `eq toggle(on) = off .` works like the function clause `def toggle(:on), do: :off`.

Maude keeps applying equations until nothing matches any more. That final term is the normal form.

On stage: slides 7–8.

### Rewrite rule

A rewrite rule says what can happen next, not what something equals. `rl [start] : idle => running .` means "from `idle`, the system may move to `running`."

Think of it as one transition in a state machine, like one clause of a `:gen_statem` state function. Several rules can apply to the same state, and that's where branching comes from.

On stage: slide 7.

### reduce

`reduce` simplifies a term with the equations and returns the normal form:

```text
reduce in SWITCH : toggle(toggle(on)) .
```

This returns `on`. It's like calling a pure function: same input, same answer, no exploring.

Goatmire's conflict gate is a `reduce`. The detector's equations take the encoded rule set and compute the list of conflicts.

On stage: slide 8, and behind every gate check.

### search and witness

`search` explores the rewrite rules, looking for a reachable state that matches a pattern:

```text
search [1] in CELL : idle =>* ready .
```

If it finds one, it returns the path that got there. That path is a witness: concrete, replayable evidence that the bad state can happen in the model.

If it finds nothing within its bound, you've learned that it gave up before finding trouble. That is "we don't know", never "it's safe".

On stage: slide 8. The talk's IoT gate does not use `search`.

### Equational detector

This is the talk's name for a checker built from equations only. The IoT detector in `priv/maude/iot-rules.maude` takes a finite, validated rule set and computes every conflict it knows how to recognise, with `reduce`.

Because the input is finite and the equations cover every case, the answer is a real decision for those four conflict types. It works like an exhaustive `case` over a closed set: no branch can be missed.

On stage: slide 8.

### state_conflict and the other three IoT conflict types

`:state_conflict` is the atom ExMaude returns when two rules write incompatible values to the same device property. The O3/O4 pair and the AGV pair are both state conflicts.

A conflict comes back as a plain map that names both rules:

```elixir
%{type: :state_conflict, rule1: "r1", rule2: "r2", reason: "Conflicting state changes"}
```

The IoT model knows exactly four types, and these are their real atoms:

- `:state_conflict` — two rules write different values to one device property.
- `:env_conflict` — two actions push a shared environment value, like room temperature, in opposite directions.
- `:state_cascade` — one rule's action satisfies another rule's trigger. A chain reaction.
- `:state_env_cascade` — the same chain, crossing between device state and the environment.

If a problem is not one of these four, this detector does not see it.

On stage: slide 9, and the LIVE 01 answer on slide 16.

### clean, conflicts, unverified

The gate returns one of three answers. `Goatmire.Verifier` never merges them.

`:clean` means the check ran to the end and found none of the modelled conflicts. `:conflicts` means it found at least one, and it names the rules. `:unverified` means there is no usable answer: Maude was unavailable, the input was rejected, or the call timed out.

`:unverified` is an error value, not a softer `:ok`. Treat it like `{:error, reason}`, never like `{:ok, []}`.

On stage: slide 13. See [section 9](#9-how-the-demo-consumes-the-results).

### Fail closed

Fail closed means that when the gate has no answer, it deploys nothing. `Goatmire.Verifier.split_on_verdict/2` admits no rules on an `:unverified` verdict.

This is an application decision, not a Maude theorem. Another application could choose to fail open. This demo chooses closed on purpose.

On stage: slide 13.

### Partitioning, interaction edges, and over-grouping

Checking every rule against every other rule gets expensive as the rule count grows. So `Goatmire.Rules.partition/1` first splits the rules into groups that can't affect each other, and Maude checks each group on its own.

Two rules land in the same group when an interaction edge joins them. There are three kinds of edge:

- The two rules are bound to the same Thing.
- The two rules write the same action target, the same device property or environment key.
- One rule writes a property that the other rule triggers on. This is the cascade edge.

The groups are the connected components of that graph. If you've written a union-find in Elixir, it's that.

Grouping by Thing alone would be wrong. A cascade crosses Things by definition, so the two rules would land in different groups, never be compared, and the gate would say `:clean`.

Over-grouping is the deliberate safety margin. The cascade edge matches on property name only, and ignores which Thing and which value. That joins some rules that can't actually interact. It costs extra comparisons, but it can't hide an interaction the model would have found.

The slide shows the counts from today's run: rules, partitions, and pairs skipped. They are not a scaling claim.

On stage: slide 15.

### Deterministic policy model

This is the AI-policy detector: `ExMaude.AI.detect_conflicts/2` over `priv/maude/ai-rules.maude`. It is built from equations, like the IoT detector, so the same input always gives the same answer. No sampling, no temperature, no second opinion.

In the talk's pattern, a language model may propose a policy as structured data. The application validates that data and hands it to this model. The model that writes the policy never grades it.

It checks exactly seven conflict types, listed in [section 7](#7-ai-policy-conflict-model). The LIVE 04 demo on slide 22 hits two of them. `:approval_gate_bypass` means a high-impact tool is invoked with no approval step before it. `:sovereignty_violation` means an action goes to a jurisdiction outside the allowed set, like the US when only the EU and Switzerland are allowed.

On stage: slides 19–22.

### TLA+, PlusCal, Alloy, SMT, and Z3

These are the usual alternatives to Maude. None of them is an Elixir library, and none is specific to IoT. They are general formal-methods tools used in cloud systems, distributed protocols, security, and hardware. When an Elixir or Erlang team uses one, it runs beside the code to check a design, not inside the application.

**TLA+** is a language for describing how a system behaves over time: its states and the steps between them. Its model checker, TLC, tries the possible orderings and reports a sequence of steps that breaks a property. Leslie Lamport created it. Amazon Web Services and Microsoft have written publicly about using it on distributed storage and replication protocols. Reach for it when the question is "can these concurrent steps interleave into a bad state?"

**PlusCal** is a friendlier front end for TLA+. You write the algorithm as pseudocode with processes and loops, and a translator turns it into TLA+. Same checker, less maths to write.

**Alloy** describes structures and the relationships between them: users, roles, permissions, files. Its analyser searches all small examples for one that breaks a rule, on the bet that most design bugs already show up in small cases. Reach for it when the question is "can this data model or access-control design contradict itself?"

**SMT** stands for Satisfiability Modulo Theories. It's a family of solvers, not one tool. You give it constraints over numbers, booleans, and similar values, like `x > 3` and `x + y == 10`. It either finds values that satisfy them or proves that none exist. SMT solvers often run inside other tools. HOMEGUARD, an IoT interference checker on the reading list, uses SMT.

**Z3** is the best-known SMT solver, from Microsoft Research. You usually drive it from Python or another host language.

Where Maude sits among them: Maude describes states as terms and changes as rewrite rules, then simplifies, searches, or checks them. That fits rule sets like this demo's well, and ExMaude plugs it into a supervision tree. The talk's point is not that Maude wins. It's that you pick the tool whose language states your property most directly.

A safe Q&A answer: "I haven't used them in production. They're the usual alternatives. I chose Maude because rule rewriting fits this problem and it runs under Elixir supervision."

On stage: slide 23. The short version is in [`qa-bank.md`](talk/qa-bank.md).


## 16. Jev and Maude — same slot, different contract

This section exists because **“why not Jev instead of Maude?”** is now a credible senior-engineer question for the talk. TypeSafe AI announced Jev on 15 September 2026 as its first public **System One Model**. The facts here were checked against TypeSafe's launch material and public API documentation on 22 September 2026. Jev is new and in early access, so re-check the official material before the conference rather than relying on this section as timeless documentation.

Primary sources:

- [TypeSafe AI — Introducing System One Models & Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev)
- [TypeSafe AI public API](https://api.typesafe.ai/docs)
- [TypeSafe AI](https://typesafe.ai/)
- [The Maude System](https://maude.cs.illinois.edu/wiki/The_Maude_System)

### What Jev actually is

Jev is not best described as “a second LLM judge.” TypeSafe presents System One Models as a model class designed for decisions inside software rather than free-form conversation. Its launch description deliberately gives up string generation and frames the interface as:

```text
program state + typed questions
  → typed probabilistic decisions + probability/confidence
```

The public interface is therefore closer to a decision primitive than a chat completion. The calling program declares the shape of the question and answer, receives a result in that shape, and also receives uncertainty information that it can threshold or escalate.

That distinction matters. **Typed output does not make the semantic judgement infallible.** A Jev result can have the correct schema and still be a wrong prediction. The probability/confidence is part of the contract precisely because the decision is probabilistic.

TypeSafe uses strong marketing language around eliminating hallucinated output. For this talk, use the narrower engineering statement:

> **Jev constrains the output shape; the judgement inside that shape remains probabilistic.**

That is the useful property without implying that Jev “cannot be wrong.”

### Why Jev and Maude look similar architecturally

They can occupy a surprisingly similar slot in an application.

With Jev:

```text
program state
  → machine decision component
  → typed probability / class / score
  → application policy
```

With the equational detector in this talk:

```text
validated rule term
  → machine decision component
  → formal model result
  → application policy
```

Neither path needs a prose answer. Both can return machine-readable values that ordinary software branches on. That is why “why not Jev instead?” is a legitimate architecture question rather than a category error.

The difference is the **meaning of the answer**.

### Jev: learned judgement under uncertainty

Jev fits questions that are meaningful but hard or brittle to reduce to exact hand-written semantics.

Examples:

- Does this agent trace look suspicious enough to require review?
- Which known category best matches this request?
- How urgent does this event appear?
- How likely is this generated action to need human escalation?
- Which route should this ambiguous case take?

Those are judgement problems. The boundary is learned rather than fully written down in application equations.

The program still owns the policy around the result. A simplified caller might decide:

```text
high confidence + low risk → continue
low confidence            → human review
high estimated risk       → escalate
```

Jev supplies a probabilistic decision. It does not own the side effect.

### Maude in this talk: explicit semantics over a validated term

The comparison with Maude must be equally precise.

Do **not** make the broad statement “Maude is deterministic.” Rewriting logic can describe branching and nondeterministic transition systems, and `search` can explore those possibilities.

The comparison on slide 25 is narrower: **Jev versus the finite equational detectors used by this talk**.

For `ExMaude.IoT.detect_conflicts/2` and the AI-policy conflict detector shown here:

- the input is validated and finite;
- the encoder constructs a Maude term;
- the selected model explicitly defines the represented conflict predicates;
- the detector reduces the same term under the same equations to the same model-relative result.

There is no learned confidence score deciding whether two encoded writes meet the definition of `state_conflict`. The semantics were written down.

That gives a stronger answer to a much smaller question.

The usual model boundary still applies. A formally correct result can be irrelevant if the encoder mistranslates the rule, a necessary property was omitted, or the model does not capture the part of reality that matters.

### The core comparison

| Dimension | Jev | This talk's Maude equational detector |
|---|---|---|
| Main job | learned judgement | explicit property checking |
| Input | program/state context plus typed questions | validated structured term |
| Output | typed probabilistic decision plus probability/confidence | model-relative detector result, wrapped by Goatmire as `clean`, `conflicts`, or `unverified` |
| Source of behaviour | trained model | explicitly encoded equations and semantics |
| Uncertainty | represented in the result | detector result is not a probability; operational failure remains `unverified` |
| Strong fit | fuzzy classification, scoring, routing, semantic risk | invariants and conflicts that can be stated exactly |
| Failure to remember | a valid typed answer can still be a wrong judgement | a correct formal result can concern an incomplete or mistranslated model |
| Application owns | thresholds, escalation and side effects | activation policy, translation tests and treatment of `unverified` |

The short distinction for rehearsal is:

> **Jev gives a probability about an ambiguous question. Maude gives the result of an explicit predicate.**

### Where they can coexist

The interesting architecture is not necessarily Jev **or** Maude.

#### Jev before Maude

```text
messy state / generated trace
        ↓
       Jev
semantic classification or risk
        ↓
threshold + validate in code
        ↓
structured candidate
        ↓
      Maude
explicit invariant check
        ↓
application activation policy
```

Jev can turn ambiguity into a typed decision that ordinary code can handle. Once a candidate reaches a property the system can state exactly, Maude can check that explicit property.

For example, Jev might judge whether an unstructured agent trajectory should be treated as high-impact. Once the validated policy is explicitly marked high-impact, the Maude policy model can enforce the exact rule that a high-impact invocation requires an approval step.

Do not use Jev to infer a fact that already has an authoritative structured source. If jurisdiction, authority, capability, or approval is already validated metadata, read the metadata.

#### Jev and Maude in parallel

The same candidate can be inspected along two independent dimensions:

```text
                         ┌→ Jev: semantic risk / ambiguity ─┐
validated candidate ─────┤                                  ├→ application policy
                         └→ Maude: explicit invariants ─────┘
```

The application combines two different contracts.

A conservative policy might say:

- a Maude conflict is a hard stop;
- Maude `unverified` follows the application's explicit fail-open/fail-closed policy;
- high Jev risk or low Jev confidence sends the candidate to review;
- a Jev decision never relabels a Maude conflict or `unverified` result as `clean`.

That last point preserves the three-verdict distinction at the centre of the talk.

#### Maude first, Jev for residual uncertainty

For a high-impact path, explicit hard constraints can run first.

If Maude finds a represented conflict, stop. If the formal invariants pass, Jev can still inspect questions intentionally outside the formal model: suspicious intent, unusual context, semantic mismatch, or review priority.

This expands practical coverage without pretending the probabilistic judgement became part of the formal proof.

### Concrete examples from the talk

**Good Maude question**

> Does this structured policy invoke a high-impact tool without a required approval step?

The property is explicit and the required fields are structured.

**Good Jev question**

> Does this free-form agent trace look suspicious enough to require review?

“Suspicious” is a semantic judgement. A typed probabilistic decision and confidence can be useful.

**Probably neither model**

> Which jurisdiction did the caller explicitly select in a validated enum field?

That is already authoritative data. Read the field in ordinary code.

**Jev plus Maude**

> Does this natural-language request appear to describe a high-impact operation, and if the resulting structured policy is high-impact, does it contain the mandatory approval step?

Jev can help with the first, fuzzy classification. After validation, Maude can check the second, explicit invariant.

### Why Jev does not make Maude obsolete

Jev addresses a real problem with AI in automation: free-form generated text is an awkward contract for ordinary software. Typed probabilistic decisions are much easier to compose, threshold and audit than prose.

That still leaves a distinction between **prediction** and **specification**.

If a property is genuinely fuzzy, forcing it into a brittle equation creates false precision. A learned decision model is appropriate there.

If a property is important and precise enough to state exactly, replacing the explicit predicate with a probability weakens the kind of claim the gate can make.

The useful boundary is therefore:

> **Use learned probabilities where the rule is genuinely fuzzy. Use explicit formal semantics where ambiguity is unacceptable.**

### Honest Q&A answer

**“Why not Jev instead of Maude?”**

> Jev is interesting because it sits in almost the same machine-facing decision slot without being a traditional text-generating LLM. It returns typed probabilistic decisions and confidence, which is useful for judgement under uncertainty. The Maude detector I'm showing handles properties I can state exactly. Given the same validated term and model, that predicate has a fixed result rather than a probability. I would use Jev for fuzzy semantic questions, Maude for explicit invariants, and keep the application policy that combines them visible.

If somebody asks which is “better,” do not rank them. Ask what kind of question the system needs to answer.

On stage: slide 25.
