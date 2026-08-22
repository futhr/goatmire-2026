---
name: unslop
description: Cut AI tells from prose. Use whenever writing or editing any text a human will read — README, docs/, runbooks, talk script, commit messages, moduledocs, code comments, chat replies. Also /unslop <file> to clean an existing file.
argument-hint: "[file]"
---

Strip the patterns that mark text as machine-written. Meaning stays, voice tightens.

## Banned words

delve, crucial, pivotal, testament, tapestry, landscape, interplay, intricate, vibrant, underscore, enduring, additionally, leverage, robust, seamless, comprehensive, holistic, foster, empower, journey, elevate, supercharge

## Banned constructions

- "serves as" / "stands as" / "acts as" → "is"
- "not just X, but Y"
- forced triads ("fast, simple, and powerful")
- empty gerund tails ("…ensuring reliability", "…highlighting the importance")
- hedge stacks ("could potentially")
- "It's important to note", "Here's where it gets interesting", "the kicker"
- vague authority ("experts believe", "many argue")
- filler: "in order to" → "to", "the fact that" → drop it

## Banned formatting

- bold sprinkled on nouns — bold only as a scan anchor
- Title Case Headings → sentence case
- decorative emoji
- em-dash chains — at most one per paragraph
- a colon splice where a period works

## Banned tone

- "Great question!", "Hope this helps!", "Let's dive in"
- preamble before the answer, recap after it
- "In conclusion", "Overall"

## House calibration (this repo)

- Voice: match README.md — plain, direct, honest about scope. The talk's thesis is honest scoping; overclaiming is off-brand.
- Code, commands, error output, and file paths stay verbatim. Never paraphrase a number.
- Domain registers compose on top of this skill: `elixir-prose` governs .ex/.exs docs and comments (hard-wrapped ~80 cols, hexdocs rules); `teach` governs README, docs/, and livebooks (pedagogic, unwrapped markdown). The wrap conventions are opposites — never let one leak into the other.

## Self-audit

Before finishing, reread once and ask: what here is obviously AI-generated? Fix it.

With a file argument: Read $ARGUMENTS, rewrite it under these rules, report what changed in two or three lines.
