# Benchee benchmarks

These are exploratory performance tools, not pass/fail tests. Benchee owns warmup and sampling; the existing `mix goatmire.benchmark` task remains the versioned JSON artifact used for talk claims.

```bash
mix run --no-start bench/rule_eval_bench.exs
mix run --no-start bench/partition_bench.exs
mix run --no-start bench/verifier_bench.exs
```

The verifier benchmark starts a listener-free local verifier profile. It requires Maude and uses `parallel: 1` so it measures the deployment gate rather than an accidental load test. Record the commit, machine, runtime and full Benchee output whenever a number is quoted. Never promote one laptop result into a portable latency or scale claim.

The JSON artifact uses schema version 2. It retains each run’s verdict, reason,
conflicts, scope, duration, and partition statistics in execution order. It also
records rule-corpus and model hashes, interpreter health, pool configuration,
and the full OTP version. `valid_measurement: false` or a mixed status means
the artifact is unsuitable for quoting a successful-verification latency.
The storm comparison uses live scheduling and random station readings; matching
configuration does not mean an identical event replay.
