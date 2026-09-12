# Testing and measurement

Goatmire separates fast deterministic checks from tests that require a real browser, deliberate load, or a local language model. The separation makes each result interpretable: CI does not silently replace an unavailable dependency with a mock, and the normal suite does not require workstation-only tools.

## Default and property suites

```bash
mix test
mix test.property --seed 0
mix coveralls
```

`mix test` includes the StreamData properties under `test/property/`. They exercise rule evaluation against independent boolean/numeric oracles, interaction partition invariants, VDA 5050 projection, and warehouse mapping over generated inputs. `mix test.property` is the focused form for repeated seeds.

Coverage is a guardrail, not the objective. The configured minimum is enforced without excluding low-coverage application modules. Additional tests must exercise a behavior, boundary, invariant, or failure mode; tests that only call lines or duplicate framework behavior are not accepted. Hardware socket loops, distributed peer boot, and external-process failures are kept visible in the report even when they require an integration environment.

## Boundary regressions

Regressions cover strict JSON object-key uniqueness at HTTP, MQTT,
generated-policy, and diagnostic-response entry points. Native telemetry object
keys normalize to JSON strings without changing scalar types. Diagnostic
templates must remain compatible with the recorded verdict and runtime fields;
a model classification alone is not conflict evidence.

A second round added regressions for the boundaries below. Each one asserts
observable behaviour, and each was first run against the unfixed code to
confirm it fails there.

- **Transport addressing.** A device subscribed to one exact topic is not
  handed another device's traffic at all, and a wildcard holder still receives
  each message exactly once. Broker deliveries reach exact-topic subscribers
  too, so the MQTT and local transports stay interchangeable.
- **Deployment provenance.** A deployment that activates nothing — a commit
  past its deadline, or a rejected addition — leaves the running set's verdict,
  mode, scenario, and run identity alone. The caller still receives the
  `:unverified` or `:conflicts` verdict for its own attempt.
- **Interpreter readiness.** An interpreter that answers `maude --version` but
  cannot load the bundled models is not treated as usable: the pool stays out
  of the supervision tree, the application still boots, `health/0` reports an
  error rather than a version, and verdicts are `:unverified`.
- **Device adapters.** A physical device's readings are accepted on the engine's
  terms (payload identity bound to the topic, property count bounded). Modbus
  refuses an unusable host, port, or timeout instead of raising into its
  supervisor. The VDA 5050 bridge bounds tracked vehicles and refuses orders it
  could not build. Only the canonical `dock-N` spelling resolves to a position.
- **Client payloads.** A malformed `/metrics` window payload falls back to the
  default instead of killing the LiveView process.
- **Subprocess lifetime.** A timed-out Codex turn signals its app server, so an
  external process that ignores stdin EOF does not outlive the request.

## Connected dashboard E2E

The browser lane follows the other Phoenix applications in this workspace: PhoenixTest drives Playwright's bundled Chromium, with no workstation Chrome or ChromeDriver coupling:

```bash
pnpm --dir assets install --frozen-lockfile
pnpm --dir assets exec playwright install chromium
mix test.e2e
```

The E2E suite boots Phoenix on loopback, waits for a connected LiveView, and uses a real headless Chromium session. It covers primary navigation, coherent storm configuration and completion, the rule conflict workflow, horizontal overflow, dashboard grid behavior, and mobile interaction targets at 1440×1000, 820×1180, 390×844, and 320×720. CI runs this lane independently from the canonical gate.

## Stress tests

```bash
mix test.stress
mix test.soak            # 30-second real-Maude wear test
SOAK_SECONDS=1800 mix test.soak  # 30-minute rehearsal
```

The stress lane drives 20,000 concurrent transport events, churns a 1,000-device supervised fleet while taking bounded snapshots, and pressures the four-worker Maude pool with 48 reductions at 16-way caller concurrency. It also injects real failures: the supervision chaos tests crash-loop demo components until their branch exhausts its restart budget and assert the endpoint and presenter clock survive with state intact, and the starvation tests saturate the pool with 96 reductions at 48-way concurrency and assert every outcome is still a verdict, never a hang. The soak lane warms the application, then repeats event storms, fleet churn, real Maude checks, and slide navigation for the requested wall-clock duration. It always checks final memory, process count, and mailbox bounds, including short runs. Both are excluded from the default suite so routine edits do not consume a shared machine's load budget.

## Real local-model tests

```bash
ollama pull qwen3.5:4b-q4_K_M
mix test.llm
```

The `:llm` tests delete the Req test adapter and make real requests to the loopback endpoint and model in `config/test.exs`. They reject non-loopback URLs. Change that checked-in test profile deliberately if the local model tag changes.

This lane validates strict diagnostic JSON and model-generated rule terms that the deterministic Maude verifier can inspect. It is excluded from normal tests and prohibited in CI by `Goatmire.CIPolicyTest`; model availability, model updates, and nondeterministic inference do not belong in the merge gate.

## Benchmarks

Benchee owns benchmark warmup and sampling; no pass/fail latency thresholds live in ExUnit:

```bash
mix run --no-start bench/rule_eval_bench.exs
mix run --no-start bench/partition_bench.exs
mix run --no-start bench/verifier_bench.exs
```

The first two report time, memory, and BEAM reductions at several scales. The third performs real partitioned Maude verification serially to avoid measuring artificial client contention. Numbers are local measurements tied to the host, runtime, interpreter, model, and commit—not production claims.
