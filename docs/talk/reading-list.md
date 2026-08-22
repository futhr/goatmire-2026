# Speaker research and reading list

Read the primary sources before rehearsing the “published conflict pattern” language. The purpose is not to borrow authority for a broader claim; it is to say precisely what the literature observed and what this demo reproduces.

| Source | Read | What it supports | What it does not support |
|---|---|---|---|
| [SOTERIA: Automated IoT Safety and Security Analysis (USENIX ATC 2018)](https://www.usenix.org/conference/atc18/presentation/celik) | Table 1, multi-app results, G.1 discussion | O3/O4 use the same contact-open event and set a switch to conflicting values; compositional checking matters | that this repository runs SOTERIA, reproduces a real household incident, or would prevent every safety outcome |
| [SOTERIA paper PDF](https://www.usenix.org/system/files/conference/atc18/atc18-celik.pdf) | pp. 154–157 | the exact primary text behind the reproduced rule pair | a production or physical-fleet claim |
| [HOMEGUARD, DSN 2020](https://ieeexplore.ieee.org/document/9153388/) | abstract, threat model, design | apps can be individually secured yet interfere collectively; installation-time checking is a credible pattern | equivalence between its SMT threat models and ExMaude's equations |
| [AutoIoT](https://arxiv.org/abs/2411.10665) | abstract, architecture, conflict-detection sections | LLM-produced automation benefits from a separate automated conflict check | that an LLM supplies formal assurance or that this repository implements AutoIoT |
| [IoTCheck project](https://plrg.ics.uci.edu/iotcheck/) | overview and paper link | independent model-checking work finds smart-home app conflicts worth checking | the effectiveness of this demo's narrower model |
| [Maude manual and system](https://maude.cs.illinois.edu/wiki/The_Maude_System) | manual chapters 1–3 | sorts, operators, equations, rewriting, reduction, and search vocabulary | application-specific safety claims |
| [ExMaude Hex package](https://hex.pm/packages/ex_maude) | README, IoT API, tests | the library surface actually used by this repository | a universal latency or production-adoption statement |

## Repository study order

1. [`../maude-for-dummies.md`](../maude-for-dummies.md)
2. `lib/goatmire/rules.ex`, especially `research_state_conflict_pair/0`
3. `lib/goatmire/verifier.ex` and `lib/goatmire/engine.ex`
4. `lib/goatmire/diagnostics/skill.ex` and `lib/goatmire/diagnostics/snapshot.ex`
5. [`delivery-audit.md`](./delivery-audit.md)
6. [`public-abstract.md`](./public-abstract.md), [`narrative.md`](./narrative.md), and [`qa-bank.md`](./qa-bank.md)

After reading, the speaker must be able to explain without notes:

- why O3/O4 is called a research-derived reproduction rather than a horror story this project prevented;
- what `clean`, `conflicts`, and `unverified` each mean;
- why observe mode exists and why it is never the recommended deployment mode;
- why BeamLens/Codex/Ollama cannot alter the Maude decision;
- which metric fields ground a diagnostic answer;
- what crosses the cloud boundary with Codex and what stays local with Ollama;
- why a benchmark distribution must travel with model, host, and commit.

If a paper or Maude-internals question goes beyond this preparation, say so and follow up. A narrow correct answer is better than improvising a broader one.
