# Slideshow tooling verdict

> Superseded 2026-08-22: the stage rig is now the merged presenter at `/talk` (see [`../../runbooks/stage-rig.md`](../../runbooks/stage-rig.md)). The deck source and exports below are a frozen archive; this file records the decision as it was made.

## Decision

Use **Marp 4.5.x** as the repository-native slide source and exporter. Keep a PDF and PPTX beside the source as stage-day fallbacks. Use Livebook for the executable tutorials and demos, not as the presentation shell.

Diggymon is not on the critical path for this talk. The neighbouring checkout contains a slideshow domain, seed/reactor work, and presenter-oriented specs, but this audit found no tested end-to-end command that turns the Goatmire deck into a conference-ready HTML/PDF/PPTX bundle. A 30-minute conference slot is the wrong place to depend on a product surface that is still converging.

## Why Marp

| Need | Marp | Slidev | Reveal.js | Livebook |
|---|---|---|---|---|
| Markdown source | yes | yes | yes/plugin | notebooks |
| HTML | yes | yes | yes | native UI |
| PDF | CLI | Playwright export | browser print | page print, not a deck contract |
| PPTX | CLI; rendered slides | CLI; rendered slides | no native PPTX path | no native PPTX path |
| Presenter notes | PPTX/PDF notes + text export | presenter UI + PPTX notes | strong speaker window | narrative cells |
| Custom design | one CSS theme | Vue/UnoCSS/theme | CSS/HTML | application UI |
| Operational weight | smallest | Node app + Chromium | web app + print flow | BEAM app/runtime |

Marp wins here because the content is mostly statements, small code fragments, and simple diagrams. Slidev is stronger when a talk needs Vue components, click-driven code animation, or embedded web interaction; those features would add more rehearsal surface than value here. Reveal.js has an excellent speaker view but a more manual PDF path and no first-party PPTX export. Livebook and Kino are excellent for interactive Elixir outputs, which is exactly why the tutorials stay there.

Official references reviewed 19 August 2026:

- [Marp ecosystem](https://marp.app/) and [Marp CLI](https://github.com/marp-team/marp-cli/blob/main/README.md)
- [Slidev exporting](https://sli.dev/guide/exporting.html)
- [Reveal.js speaker view](https://revealjs.com/speaker-view/) and [PDF export](https://revealjs.com/pdf-export/)
- [Kino](https://kino.hexdocs.pm/)

## Reproducible build

Node 18+ and a current Chrome/Chromium are required for browser-backed export. The version is pinned in this directory rather than installed globally.

```bash
cd docs/talk/slides
npm install
npm run build
```

Outputs land in `dist/`:

- `goatmire-2026.html` — local browser presentation;
- `goatmire-2026.pdf` — projector-independent fallback;
- `goatmire-2026.pptx` — Keynote/PowerPoint/LibreOffice fallback;
- `goatmire-2026-notes.txt` — printable presenter notes;
- numbered PNGs — visual regression and fallback stills.

Marp's normal PPTX export renders each slide as an image. That preserves the design reliably but does not produce editable slide text. Its editable PPTX mode is explicitly experimental, has lower rendering fidelity, requires LibreOffice, and drops presenter notes, so it is not used here.

## Stage-day hierarchy

1. Present the local PPTX in Keynote or PowerPoint so presenter notes and the next-slide view are available.
2. Keep the PDF open in Preview as the instant fallback.
3. Keep the static HTML available for a browser-only machine.
4. Run live demos in the already-booted dashboard and Livebook tabs.
5. If a live beat fails its health check, show its recorded still/cast and say that it is the fallback.

No stage path requires an account, a hosted slide service, or Diggymon.
