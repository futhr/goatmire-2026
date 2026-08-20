# Maude, ExMaude, and the Goatmire Demo

This is the technical study guide behind “Zero Alert Storms: Formal Verification for IoT Automation.” It describes the code that exists in the local `ex_maude` and `goatmire-2026` repositories as of 19 August 2026. When this guide and the code disagree, the code and its tests win.

## 1. The useful mental model

Maude models a domain with:

- **sorts**: types;
- **operators**: constructors and functions;
- **equations**: deterministic simplification;
- **rewrite rules**: possible state transitions.

Two commands matter most here:

```text
reduce in MODULE : term .
search [1] in MODULE : initial =>* pattern .
```

`reduce` normalizes a term with equations. `search` explores transitions described by rewrite rules. These operations support different claims:

- A detector implemented as complete equations over validated finite input can decide the conflict predicates encoded by that detector.
- A search result is a concrete reachable witness.
- No witness inside a depth bound is not an unbounded safety or liveness proof. ExMaude reports clean bounded safety/liveness searches as `:unverified`.

The model boundary matters. “No modeled conflict found” does not mean “the system is safe in every respect.”

## 2. Small Maude example

```maude
fmod SWITCH is
  sort State .
  ops on off : -> State [ctor] .
  op toggle : State -> State .

  eq toggle(on) = off .
  eq toggle(off) = on .
endfm
```

Then:

```text
reduce in SWITCH : toggle(toggle(on)) .
```

returns `on`. This is close to repeatedly applying Elixir pattern-matching function clauses until the term reaches a normal form.

Rewrite rules use `rl` or `crl` and express transitions rather than equalities. Search can explore their possible interleavings. That is useful for state machines and cascade witnesses, but its cost and conclusion depend on the model, branching factor, search form, and depth.

## 3. What ExMaude is

ExMaude is an Elixir library that supervises Maude subprocesses and exposes:

```elixir
ExMaude.reduce(module, term, opts \\ [])
ExMaude.rewrite(module, term, opts \\ [])
ExMaude.search(module, initial, pattern, opts \\ [])
ExMaude.load_file(path, opts \\ [])
ExMaude.load_module(source, opts \\ [])
ExMaude.execute(command, opts \\ [])
ExMaude.version()
```

It starts no pool automatically. A consumer owns the pool in its supervision tree:

```elixir
children = [
  ExMaude.Pool.child_spec(
    name: :ex_maude_pool,
    pool_size: 1,
    pool_max_overflow: 0
  )
]
```

That one-worker configuration is the smallest useful consumer example. This talk application currently starts four workers so the dashboard and rehearsal tools can issue independent reductions without checkout contention.

ExMaude supports named pools. Pool identity, loaded modules, and preloads are scoped so independent consumers do not contaminate one another's Maude sessions.

## 4. Installing Maude

ExMaude 0.4 is an MIT-licensed Hex package. It does **not** bundle the GPL-licensed Maude interpreter.

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

The ExMaude Git checkout contains development binaries for selected hosts, but that is not the Hex-package contract. Always display `ExMaude.version/0` from the actual rehearsal machine rather than promising a version in the script.

## 5. Backends

The public backend choices are:

- **Port**: default; a separate Maude process over plain pipes. PTY mode is opt-in.
- **C-Node**: a separate C bridge process communicating over Erlang Distribution.
- **NIF**: a Rustler extension that manages a Maude subprocess. The Maude child remains separate, but native code is loaded into the BEAM and therefore has a larger failure blast radius.

There is no justified universal latency ranking in this repo. Choose with a reproducible workload and operational requirements. Source-building the NIF is explicit:

```bash
EX_MAUDE_BUILD=1 mix deps.compile ex_maude
```

A local ignored NIF artifact must not force Rustler into a path-based consumer.

## 6. IoT conflict model

`ExMaude.IoT.detect_conflicts/2` targets `priv/maude/iot-rules.maude`, currently 531 lines. The schema is inspired by the conflict categories discussed by AutoIoT, but it is a smaller custom model, not an implementation of that full system.

The high-level detector returns four modeled categories:

1. state conflict;
2. environment conflict;
3. state cascade;
4. state-environment cascade.

An empty list means those definitions found no conflict in the validated encoded rules. It does not cover every physical hazard, temporal requirement, runtime authorization decision, or deployment condition.

ExMaude also exposes bounded IoT safety and liveness helpers. Counterexamples are meaningful witnesses. Exhausting the configured bound without one returns `:unverified`; it is not relabelled `:safe` or `:live`.

## 7. AI policy conflict model

`ExMaude.AI.detect_conflicts/2` targets `priv/maude/ai-rules.maude`, currently 756 lines. It implements exactly seven conflict types:

1. `:tool_call_conflict`;
2. `:capability_shadowing`;
3. `:pack_tool_composition_mismatch`;
4. `:sovereignty_violation`;
5. `:authority_escalation`;
6. `:approval_gate_bypass`;
7. `:agent_loop_cascade`.

There is no `ExMaude.AI.verify_property/2`. Budget-cascade, cost-ceiling-infeasibility, and provider-routing-infeasibility are not public detector results and must not appear as implemented talk features.

Example:

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

Adding an explicit approval constructor before the high-impact invocation makes that particular detector clean:

```elixir
invocations: [
  {:require_approval, "dosing_high_delta"},
  {:invoke_tool, "dose", %{}, "high_impact", :eu}
]
```

The supported conclusion is not “the policy is safe.” It is “the current detector did not find any of its seven modeled conflicts.”

## 8. Generate, do not imitate, the Maude command

The talk's Scenario 5 uses the real encoder:

```elixir
{:ok, encoded_policy} = ExMaude.AI.Encoder.encode_rules(policy)
jurisdictions = ExMaude.AI.Encoder.encode_jurisdiction_set([:eu])

command =
  "reduce in AI-CONFLICT-DETECTOR : " <>
    "detectAllConflicts(#{encoded_policy}, #{jurisdictions}) ."

{:ok, output} = ExMaude.execute(command)
```

This avoids a common documentation failure: a hand-written “raw command” that drifts away from the encoder's actual constructors.

The trust boundary is:

```text
validated Elixir data
  → encoder
  → generated Maude term
  → selected module and interpreter
  → parsed typed result
  → caller's activation policy
```

Every arrow deserves tests. Formal reasoning over a mistranslated input proves the wrong model precisely.

## 9. How the demo consumes the results

`Goatmire.Verifier` separates three outcomes and never merges them:

- `:conflicts` — a concrete typed conflict, with the rule ids;
- `:clean` — no conflict of the types this detector models;
- `:unverified` — the detector could not run at all.

Skips, unavailable backends, encoder rejections, and clean bounded searches all land in `:unverified`. None of them becomes a success claim.

`split_on_verdict/2` fails closed: an unverified rule set admits nothing. It also withholds *both* rules named in a conflict rather than guessing which author was right.

The activation layer owns fail-open/fail-closed policy in general — a library availability error is not evidence that input is safe, and this demo takes the conservative side of that choice explicitly rather than by default.

## 10. The five demos

Everything runs from this repository. Scenarios 1, 3 and 5 need only the interpreter. Scenario 2 additionally boots the fleet and the engine. Scenario 4 additionally needs the configured language model to be reachable; otherwise skip it and continue with deterministic Scenario 5.

The entire stage fleet is simulated, and the storm counters are this machine's measured output—not customer incidents and not physical-fleet evidence.

Scenario 5 is the one that depends on nothing but the interpreter:

```elixir
Goatmire.VerificationDemo.run()
```

It asserts three exact outcomes:

- missing approval → `[:approval_gate_bypass]`;
- explicit approval → `[]`;
- US invocation under EU/CH allowance → `[:sovereignty_violation]`.

The application starts a four-worker ExMaude pool, and tests reject any drift in these results — a library change that quietly alters a verdict is caught in rehearsal rather than on stage.

## 11. Performance claims

Do not memorize `500 µs`, `600 ms`, an 80% pre-filter ratio, or a scale number. None is a portable property of Maude or ExMaude.

A defensible benchmark records:

- repository revisions;
- Maude and OTP versions;
- backend and pool settings;
- host OS/architecture;
- exact rule corpus and search bounds;
- cold versus warm execution;
- sample count and reported distribution;
- timeouts and errors.

The stage script should read the displayed measurement from the final rehearsal build. A timeout remains an error or `:unverified`.

## 12. Security and operational boundaries

- Validate identifiers and predicates before encoding them.
- Never create atoms from untrusted strings.
- Escape strings through the library encoder; do not interpolate raw user input into Maude commands.
- Keep command text out of telemetry unless explicitly enabled and safe.
- Treat module sources and file paths as trusted administrative input.
- Bound pool size, checkout time, command time, and search depth.
- Restart workers after timeout because their interpreter state is uncertain.
- Keep independently named pools isolated.
- Record model revision, interpreter version, validated input, and result when building an audit artifact.
- Do not claim that such an artifact satisfies a regulation without a separate documented control mapping.

## 13. Honest Q&A answers

**Does ExMaude prove my application correct?**

No. It evaluates properties of the encoded model. Encoder correctness, omitted properties, runtime behavior, and the deployment environment remain outside that result.

**What does an empty conflict list mean?**

No conflict represented by that detector was found for that input.

**What does a bounded search prove?**

A returned counterexample is reachable in the model. No counterexample within the bound is reported as unverified, not as an unbounded proof.

**Can it verify an LLM?**

No. It can inspect validated structured output produced by an LLM.

**Does it run on constrained edge hardware?**

This talk does not demonstrate that. Maude and the simulated fleet run on the demo laptop and support containers. Validate a compatible interpreter and benchmark before making any edge-host claim.

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
