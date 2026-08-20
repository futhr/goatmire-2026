# Slide design system

The deck and demo use one visual language: a quiet workspace inspired by
Livebook, not a conference-site imitation.

## Direction

The audience should feel that they are looking at an engineer's working
surface:

- warm off-white canvas (`#f8fafc`);
- white code and evidence surfaces;
- slate typography and hairline borders;
- indigo for structure and navigation;
- teal, red, and amber used only for `clean`, `conflicts`, and `unverified`;
- system sans-serif for speech, system monospace for terms and measurements;
- no gradients, stock imagery, decorative 3-D, fake terminal chrome, or
  cyberpunk effects.

This direction is deliberately projector-safe. White-on-black code can bloom
in bright rooms; thin neon accents disappear; dense dark dashboards make a
speaker fight the screen. The light surfaces here match the Livebook demos and
keep the projected hierarchy stable.

## Typography and spacing

The 16:9 deck uses a 1280 × 720 reference canvas.

| Element | Target |
|---|---:|
| Title slide | 60–68 px |
| Slide heading | 42–50 px |
| Supporting statement | 25–30 px |
| Body | 22–25 px |
| Code | 20–24 px |
| Eyebrow / source | 13–16 px |

Slides use a 72 px outer margin, one main claim, and at most two content
regions. Paragraphs stay left-aligned. Code examples are cropped to the line
that carries the argument; the repository remains available for full context.

## Semantic colour

| Verdict | Foreground | Surface | Meaning |
|---|---|---|---|
| `clean` | `#0f766e` | `#ccfbf1` | detector ran; no modelled conflict found |
| `conflicts` | `#dc2626` | `#fee2e2` | concrete modelled conflict found |
| `unverified` | `#b45309` | `#fef3c7` | detector did not produce a verdict |

The words always travel with the colours. No conclusion relies on colour
alone.

## Narrative rhythm

Twenty-five slides fit the 30-minute slot. The deck carries roughly 22 minutes
of speech, 6 minutes of live interaction, and 2 minutes of recovery margin.

1. **Incident** — two sensible rules become one absurd system.
2. **Method** — terms, equations, rules, reduction, and search.
3. **Gate** — one representation, three verdicts, fail-closed activation.
4. **Evidence** — three IoT demos and one policy demo.
5. **Transfer** — where the method fits, what it omits, and the closing rule.

Live-demo slides are intentionally sparse. They are visual bookmarks while the
speaker moves to the dashboard or Livebook, and clean recovery points if a
fallback recording is needed.

## Source files and exports

- [`deck.md`](./deck.md) — Marp Markdown, presenter cues, and source notes.
- [`theme.css`](./theme.css) — the deck's complete custom theme.
- [`script.md`](../script.md) — the rehearsable spoken version.
- [`tooling.md`](./tooling.md) — the no-Diggymon build decision and runbook.

The deck must be rehearsed from exported PDF/PPTX, not only from a development
browser. Every export is opened without a network connection before stage day.
