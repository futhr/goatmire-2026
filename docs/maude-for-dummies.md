# Maude, ExMaude, and the Goatmire Demo

This is the technical study guide behind “Zero Alert Storms: Formal Verification for IoT Automation.” It describes the code that exists in the local `ex_maude` and `goatmire-2026` repositories as of 19 August 2026. When this guide and the code disagree, the code and its tests win.

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

And when a bounded search comes back empty, that means it gave up before finding trouble. That's “we don't know,” never “it's safe.” ExMaude reports it as `:unverified`.

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

`ExMaude.IoT.detect_conflicts/2` targets `priv/maude/iot-rules.maude`, currently 531 lines. The schema is inspired by the conflict categories discussed by AutoIoT, but it is a smaller custom model — not an implementation of that full system.

The four modeled categories:

1. **State conflict** — two rules write incompatible values to the same device property. The O3/O4 case.
2. **Environment conflict** — two actions push a shared environmental property in opposite directions.
3. **State cascade** — one rule's action satisfies another rule's trigger. A chain reaction.
4. **State–environment cascade** — the same chain, crossing between device state and the environment.

An empty list means one thing: these four conflicts aren't in the validated rules you handed it. It says nothing about physical hazards, timing requirements, runtime authorization, or deployment conditions — the model doesn't encode those, so the detector can't see them.

ExMaude also exposes bounded IoT safety and liveness helpers. A counterexample is a meaningful witness. Exhausting the bound without one returns `:unverified` — the search gave up before finding trouble, and that is never relabelled `:safe` or `:live`.

## 7. AI policy conflict model

Can it check agent policies too? Yes — same mechanism, different model.

`ExMaude.AI.detect_conflicts/2` targets `priv/maude/ai-rules.maude`, currently 756 lines. It implements exactly seven conflict types:

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
- `:unverified` — the detector could not run at all.

Skips, unavailable backends, encoder rejections, and clean bounded searches all land in `:unverified`. None of them becomes a success claim. A bad answer, a good answer, and no answer are three different things.

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

> Formal methods make a narrow claim strong; they do not make a broad claim true.
