# Slide design system

The deck and demo use one visual language: a quiet workspace inspired by
Livebook, not a conference-site imitation.

## Direction

The audience should feel that they are looking at an engineer's working
surface:

- warm off-white canvas (`#f8fafc`);
- white code and evidence surfaces;
- slate typography and hairline borders;
- purple (`#533a73`) for structure and navigation;
- teal, magenta, and amber used only for `clean`, `conflicts`, and `unverified`;
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
| `clean` | `#00695f` | `#dff1ee` | detector ran; no modelled conflict found |
| `conflicts` | `#d9539b` | `#fce7f2` | concrete modelled conflict found |
| `unverified` | `#b45309` | `#fef08a` | detector did not produce a verdict |

Teal, magenta, and amber, harmonised with the `#533a73` accent and checked
with a CVD validator: the worst adjacent pair separates by ΔE 10.5 under
protanopia and 18.5 with normal vision. The green/red/amber set they replaced
failed both — red and amber sat ΔE 1.9 apart for deuteranopes and only 10.3
apart with full colour vision, on the talk's most important distinction. Red
is retained for infrastructure failure, which is not a verdict.

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

Live-demo slides are intentionally sparse. In the merged presenter the live
pane opens beside them, so the card only anchors the beat — and it is a clean
recovery point if a fallback recording is needed.

## Source files and exports

- [`deck.md`](./deck.md) — Marp Markdown, presenter cues, and source notes.
- [`theme.css`](./theme.css) — the deck's complete custom theme.
- [`manuscript.md`](../manuscript.md) — the rehearsable spoken version.
- [`tooling.md`](./tooling.md) — the no-Diggymon build decision and runbook.

This design system also drives the merged presenter at `/talk`, which is the
stage surface — the Marp deck and its exports are a frozen archive
(see [`tooling.md`](./tooling.md)).
