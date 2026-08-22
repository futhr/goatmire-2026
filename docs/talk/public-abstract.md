# Public talk copy

## Action required

Ask the Goatmire organiser to replace the currently exposed introduction. As of 2026-08-20 it says the demo uses a 260-line specification, takes about 500 microseconds, has zero conflicting rules in production, includes real IoT horror stories, and integrates an Ash platform with Nerves edge gateways. Those statements are not supported by the current repository or stage plan.

Public page: <https://goatmire.com/talk/zero-alert-storms-formal-verification-for-iot-automation>

## Approved minimal correction

### Zero Alert Storms: Formal Verification for IoT Automation

When an IoT platform composes automation rules across Things, rules can conflict. Two rules targeting the same device with opposing states. One rule's output triggering another in a cascade. Alert storms that flood operators with notifications.

I wrote ExMaude—an Elixir library that supervises the Maude rewriting-logic interpreter—to catch these conflicts before activation. In this simulation, ExMaude checks the same rule representation the runtime evaluates and returns one of three results: conflicts, clean within the model, or unverified. Four modelled conflict categories. The live demo compares observe and enforce modes under the same synthetic load.

This talk covers the problem (with a published smart-home conflict pattern), the solution (Maude rewriting logic explained for Elixir developers), and the integration (a narrow deployment gate in a Phoenix/BEAM simulation). BeamLens and Codex or local Ollama explain a bounded telemetry snapshot; Maude remains the deterministic decision maker.

Includes a live demo.

## Short organiser note

> The implementation and demo scope changed after submission. Could you apply the corrected copy below? It keeps the original title, examples, problem–solution–integration structure, and live-demo promise while removing unsupported production, latency, hardware, and platform details.
