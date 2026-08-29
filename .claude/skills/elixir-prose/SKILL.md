---
name: elixir-prose
description: Moduledoc, @doc, @spec, and code-comment style for this codebase. Use when writing or editing any prose inside .ex/.exs files.
metadata:
  path-scope: "lib/**/*.ex,test/**/*.exs"
---

Senior voice, hexdocs discipline. The best calibration is already in this repo — match it, don't invent a new register.

Apply this skill only to prose inside `lib/**/*.ex` and `test/**/*.exs`.
Markdown, Livebook, and other documentation belong to the teaching style owner.

## Hexdocs rules (non-negotiable)

- First line of every `@moduledoc`/`@doc`: one concise sentence, period at the end. ExDoc uses it as the summary.
- Sections inside docs start at `##` — first-level headings belong to module and function names.
- Code references in backticks, functions with arity (`verify/2`), full module names (`Goatmire.Verifier`).
- Examples under `## Examples` with `iex>` when they can be doctests.
- Every public function: `@doc` + `@spec`. Private functions never get `@doc` — a `#` comment if they need anything.
- Modules that are not API surface: `@moduledoc false`.

## Line breaks

Prose in `.ex`/`.exs` hard-wraps at ~80 columns like the rest of this codebase. This rule is for Elixir files only — never carry the wrap into `.md` or `.livemd`, which use one line per paragraph.

## The house voice (quote-calibrated, from this repo)

A moduledoc earns its place by stating what the module *decides*, not what it contains:

> `:unverified` is never collapsed into `:clean`; an availability failure must not look like a proof. — `Goatmire.Verifier`

> Nothing here can deploy rules or actuate a device. — `Goatmire.Diagnostics.Sampler`

A comment states the constraint the code can't show — the why, never the what:

> A rule is only conflict-free relative to the set it is joining. — `GoatmireWeb.RuleLive`

> Markdown is converted once here rather than in render/1 — the snapshot refresh re-renders every second and must not re-run MDEx per message. — `GoatmireWeb.DiagnosticsLive`

Write like that: one load-bearing sentence beats three descriptive ones. If a doc line would survive deletion with nothing lost, delete it.

## Never

- Narrating the next line ("# increment the counter").
- Docs that restate the function name ("Gets the status." on `get_status/0`).
- Hedge words in specs or docs — the type says what it says.
