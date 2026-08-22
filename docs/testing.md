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

## Connected dashboard E2E

Wallaby requires Google Chrome and a compatible ChromeDriver. The helper reads the installed Chrome version and selects the matching build from Google's official Chrome-for-Testing catalogue:

```bash
scripts/install-chromedriver.sh
mix test.e2e
```

The E2E suite boots Phoenix on loopback, waits for a connected LiveView, and uses a real headless Chrome session. It covers primary navigation, coherent storm configuration and completion, the rule conflict workflow, JavaScript errors, horizontal overflow, dashboard grid behavior, and mobile interaction targets at 1440×1000, 820×1180, 390×844, and 320×720.

Screenshots from failed runs are written to `tmp/wallaby/` and are ignored by Git. CI runs this lane independently from the canonical gate.

## Stress tests

```bash
mix test.stress
mix test.soak            # talk-length wear test; SOAK_ITERATIONS=60 for longer
```

The stress lane drives 20,000 concurrent transport events, churns a 1,000-device supervised fleet while taking bounded snapshots, and pressures the four-worker Maude pool with 48 reductions at 16-way caller concurrency. It also injects real failures: the supervision chaos tests crash-loop demo components until their branch exhausts its restart budget and assert the endpoint and presenter clock survive with state intact, and the starvation tests saturate the pool with 96 reductions at 48-way concurrency and assert every outcome is still a verdict, never a hang. The soak lane repeats event storms, fleet churn, verifications, and slide navigation and asserts memory and process counts stay flat. Both are excluded from the default suite so routine edits do not consume a shared machine's load budget.

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
