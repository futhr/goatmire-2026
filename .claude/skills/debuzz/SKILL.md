---
name: debuzz
description: Rewrite text for a named audience without theatrics. Use only when the user explicitly invokes debuzz; never select it implicitly for ordinary editing.
metadata:
  argument-hint: "[colleague|manager|director] [file or text]"
  legacy-claude-disable-model-invocation: "true"
---

Translate the target — a file path, pasted text, or with no target your own previous reply — into plain English. Print the translation verbatim. Do not tidy it afterwards; tidying reintroduces the voice being removed.

This skill is explicit-only. Do not apply it unless the user directly invokes
`debuzz` and supplies, or clearly implies, one of the modes below.

Modes:

- colleague — same content, every file path and code block intact, zero theatrics.
- manager — what happened, why it matters, what's next. About a third the length, no code.
- director — three to five sentences: outcome, impact, ask.

Kill on sight: dramatic pacing, "here's where it gets interesting", "the kicker", rhetorical scaffolding ("three things jumped out at me…"), storytelling wrapped around plain facts.

Apply the unslop rules to the result.
