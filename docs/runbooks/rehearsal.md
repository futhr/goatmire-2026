# Rehearsal runbook — 30-minute stage cut

Rehearse the system that will actually be shown: simulated fleet, research-derived rule pair, observe/enforce comparison, Maude verdicts, and BeamLens diagnostics. No physical hardware belongs in the critical path.

Companion setup: [`demo-setup.md`](./demo-setup.md). The displays, the presenter at `/talk`, the memorized speech, and the fallback ladder are one documented arrangement in [`stage-rig.md`](./stage-rig.md). The speech itself is learned from [`../talk/memorize.md`](../talk/memorize.md).

## Success conditions

A dress rehearsal passes only when all of these are true:

- spoken duration is at most 27:30, leaving 2:30 recovery margin
- Scenario 1 is introduced as a SOTERIA-derived reproduction
- Scenario 2 says **observe** and **enforce**, uses the same staged load, and reads current counters rather than memorized ones
- `clean`, `conflicts`, and `unverified` are each described accurately
- `/diagnostics` is the primary operational view after the storm
- the answer cites snapshot fields and labels observation versus inference
- the active Codex/Ollama provider and privacy boundary are spoken aloud
- the Metrics pane remains optional raw corroboration
- the talk ends with properties not proved by the model.

## Before every rehearsal

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test --include maude
mix goatmire.health
```

For a full-system rehearsal:

```bash
ollama serve
make diagnostics-demo
```

Open the presenter (`make talk`) and pin one Livebook tab for LIVE 04. Every other demo surface is a pane inside `/talk`.

Reset the talk clock (`↺` in the chrome) and application state, and use the recorded rehearsal fleet size, tick rate, and duration. Confirm the provider badge before sending a prompt; page load itself should not consume model usage.

## Phase 1 — Technical truth pass

Run without slides and narrate what each system component can establish.

1. Run Scenario 1. Point to the contact-open trigger, switch-on/off actions, witness, rule IDs, and work statistics.
2. Read the SOTERIA paragraph in the manuscript exactly. Any accidental “incident we prevented” language fails the pass.
3. Run Scenario 3 and say “no encoded conflict found,” never simply “safe.”
4. Stop or misconfigure Maude and confirm `unverified` deploys nothing.
5. Run Scenario 2 in observe and enforce mode. Confirm run ID, scenario, mode, verdict, and counters are associated in the diagnostic snapshot.
6. Ask BeamLens the rehearsed question. Verify every claimed observation can be traced to a displayed structured field.
7. Corroborate one field against the Metrics pane raw series.

Repeat until there is no ambiguity about the difference between simulated behavior, formal decision, and generated explanation.

## Phase 2 — Provider fallbacks

Rehearse each branch; do not wait for conference Wi-Fi to discover it.

### Codex primary

- Confirm the CLI account is a ChatGPT-plan account.
- Confirm usable plan quota is reported.
- Send one prompt and check the provider badge says Codex.
- Say aloud that included plan usage is consumed and no API-key/pay-per-token path is enabled.

### API-key refusal

- Use the automated test or a fake runner, not a real paid key.
- Confirm account type `apiKey` is refused and the visible reason names the policy.
- Confirm Ollama becomes active.

### Quota fallback

- Use the automated provider test to simulate exhausted quota.
- Confirm the visible fallback reason and Ollama answer.

### Ollama-only

- Sign Codex out or make it unavailable in the rehearsal environment.
- Confirm `qwen3.5:4b-q4_K_M` is installed and answers within the timeout.
- Say aloud that prompt and snapshot stay local in this mode.

### Neither provider

- Stop Ollama and make Codex unavailable.
- Confirm the formal pages still work and diagnostics shows unavailability.
- Deliver the structured-card/Metrics fallback in under 30 seconds.

## Phase 3 — Timed slide pass

Use [`../talk/manuscript.md`](../talk/manuscript.md) word for word. Record timestamps at every live transition.

| Checkpoint | Target |
|---|---:|
| research-derived pair introduced | 01:35 |
| Maude vocabulary complete | 08:25 |
| three verdicts complete | 11:45 |
| LIVE 01 starts | 13:45 |
| LIVE 02 starts | 15:15 |
| LIVE 03 BeamLens starts | 18:15 |
| AI-policy transfer starts | 19:20 |
| closing begins | 26:25 |
| stop | no later than 27:30 |

If late, use the hard-cut map in the manuscript. Never cut the three-verdict slide, the BeamLens/Maude boundary, or the final scope sentence.

## Phase 3b — Recorded performance pass

Caption analysis established the talk's verbal and structural patterns; it cannot measure presence. Record one uninterrupted, full-speed pass from audience eye level while also capturing the projected screen. Review it three ways before editing the manuscript again:

1. **Audio only:** the alert-storm promise arrives before biography; the three verdicts are audibly distinct; qualifications sit beside their claims; no section sounds rushed merely because it is precise.
2. **Video muted:** gaze returns to the room after every screen change; gestures mark the rule pair and the three verdicts without constant motion; the final sentence is followed by stillness rather than a second ending.
3. **Screen recording:** every live beat follows target → action → pause → result; the pointer rests on the named evidence; provider, verdict, and observation/inference labels remain legible at the venue's resolution.

The pass fails if any live action begins before the audience is told where to look, if a boundary statement is delivered as an apology, or if the close is followed by another takeaway. Fix recurring delivery problems first; change the written structure only when the same problem survives two recorded passes.

## Phase 4 — Benchmark and claim audit

On the final talk laptop and commit:

```bash
mix goatmire.benchmark --runs 10 --output tmp/goatmire-benchmark.json
```

Store the JSON alongside rehearsal notes. Before speaking any latency or scale number, verify it is in that artifact and accompany it with:

- rule and partition count
- pairs considered and skipped
- median and p95
- host/runtime/model/commit scope
- verdict.

Run the contradiction scan:

```bash
rg -n "260 lines|500 ?[µμu]s|zero conflicting rules in production|real IoT horror|gate off|gate on|Raspberry|NeoPixel|hardware-setup" \
  README.md config/config.exs docs/talk/manuscript.md docs/talk/slides/deck.md \
  docs/talk/qa-bank.md docs/runbooks/demo-setup.md docker/README.md
```

Expected result: no unsupported stage copy. Research discussion may include the phrase “real IoT horror stories” only when explicitly explaining why it was replaced.

The scan exists because these claims and paths were deliberately retired and must not reappear:

- hardware purchase, Raspberry Pi, NeoPixels, or a physical bench device
- “real IoT horror stories” framed as personal or customer incidents
- “gate off/on” language
- a static Grafana board as the main diagnostic demo
- API-key/pay-per-token OpenAI access
- 260-line, 500-microsecond, production-zero, or universal-scale claims
- Ash/Nerves/physical-edge integration claims
- treating LLM prose as formal evidence
- treating `clean` as whole-system safety.

## Phase 5 — Hostile conditions

Run complete passes with one fault injected at a time:

- no network
- Codex unavailable
- Ollama unavailable
- both diagnostic providers unavailable
- Maude unavailable (`unverified` path)
- MQTT support stack unavailable (local transport fallback)

- browser zoom reset or projector resolution reduced
- one live action takes 30 seconds.

The objective is not to hide failures. Each failure must become a short, accurate boundary statement and a prepared next action.

## Audience review prompts

Ask a reviewer to interrupt with:

- “Did SOTERIA use Maude?”
- “Did this happen to one of your customers?”
- “Does clean mean the automation is safe?”
- “Why isn't Grafana enough?”
- “Is Codex making the deployment decision?”
- “Are you sending operational data to OpenAI?”
- “Does this incur API token charges?”
- “What if the explanation is wrong?”
- “What if Maude times out?”
- “How fast is it at 100,000 rules?”

Use [`../talk/qa-bank.md`](../talk/qa-bank.md) to score the answers. Any answer that widens the evidence fails even if it sounds persuasive.

## Code-freeze checklist (target 2026-09-15)

- [ ] Send [`../talk/public-abstract.md`](../talk/public-abstract.md) to the organiser and verify the public page has changed.
- [ ] Freeze the final commit and run the complete quality gate.
- [ ] Choose and record the final Scenario 2 fleet size, tick rate, and duration.
- [ ] Run one full Codex-primary rehearsal and one offline Ollama-only rehearsal with the exact fixed model.
- [ ] Open Scenario 5 in the Livebook container once so it caches the compiled project.


## Final day checklist

- [ ] Pin the final commit and record dirty state.
- [ ] Save the final benchmark artifact.
- [ ] Run `mix goatmire.health` after arriving at the venue.
- [ ] Confirm the exact Ollama model is already present.
- [ ] Confirm Codex account type/quota or choose Ollama-only deliberately.
- [ ] Run one SOTERIA-derived conflict and one clean set.
- [ ] Run one observe/enforce comparison with the final seed.
- [ ] Ask one diagnostic prompt and inspect grounding.
- [ ] Confirm `unverified` and both-provider failure fallbacks.
- [ ] Disable notifications, sleep, VPN, and automatic updates.
- [ ] Keep terminal font and browser zoom projector-readable.
- [ ] Begin the close by 26:25 and stop after the final sentence.

After the talk, record the actual provider, scenario parameters, benchmark artifact, and any deviations. Do not retrofit a production claim from a good conference demo.
