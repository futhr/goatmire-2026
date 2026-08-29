---
name: teach
description: Pedagogic style for the talk and teaching docs. Use when writing or editing README.md, anything in docs/, notebooks, or livebooks — and /teach [file] to rewrite an existing doc that reads like a research paper.
metadata:
  argument-hint: "[file]"
  path-scope: "README.md,docs/**/*.md,notebooks/**/*.livemd,priv/livebooks/**/*.livemd"
---

The reader is a senior Elixir developer who has never seen Maude. The speaker has to *say* this material on stage and understand every sentence they say. Write for that person, not for reviewers.

Apply this skill only to `README.md`, `docs/**/*.md`,
`notebooks/**/*.livemd`, and `priv/livebooks/**/*.livemd`. Elixir source prose
belongs to `elixir-prose`.

## The failure mode being fixed

The current docs are precise but written like a defense — sentences built to be unfalsifiable instead of understood. "A detector implemented as complete equations over validated finite input can decide the conflict predicates encoded by that detector" is correct and teaches nothing. Keep the precision, change the delivery: say it plainly first, then let the exact claim land.

## Rules

- Explain every Maude concept through an Elixir concept the reader already owns. The repo's best existing line does this: "close to repeatedly applying Elixir pattern-matching function clauses until the term reaches a normal form." That's the model — one analogy per concept, from *this* reader's world.
- Example first, definition second. Show the four-line Maude module, then name the pieces.
- Read-aloud test: if a sentence can't be spoken on stage in one breath, split it.
- One idea per paragraph. "You" address is fine. Contractions are fine.
- Verbs over nominalizations: "the encoder scopes each pool" not "pool identity is scoped".
- No semicolon-chained definition lists ("sorts: types; operators: …"). Give each term its own plain sentence.
- Never soften the honest-scoping claims — restate them in speakable words instead. "No witness within the bound" becomes: the search gave up before finding trouble — that's "we don't know", never "it's safe".
- Markdown: one line per paragraph, no hard wraps. This is the opposite of the .ex moduledoc convention; don't let the two leak into each other.
- `docs/talk/script.md` is spoken word: shorter sentences, natural rhythm, no citation-speak.

## Calibration

The register to hit is the README's opening paragraph and the talk's memorable line: "Formal methods make a narrow claim strong; they do not make a broad claim true." Plain words carrying an exact claim.

With a file argument: Read $ARGUMENTS, rewrite section by section under these rules, preserve every technical claim and code block exactly, and flag any sentence whose meaning you were unsure of rather than guessing.
