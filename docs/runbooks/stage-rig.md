# Stage Rig — How the Talk Is Physically Delivered

One laptop, two screens, one browser. The audience never sees a window switch, and the speech is never memorised — the notes travel with the slides.

Companions: [`demo-setup.md`](./demo-setup.md) for booting the system, [`rehearsal.md`](./rehearsal.md) for the practice procedure.

## Displays

Extended desktop, never mirrored. The projector gets one fullscreen Chrome window; the laptop screen is the speaker's private side: presenter view, tmux, and the script.

One-time macOS settings (System Settings → Desktop & Dock → Mission Control): "Displays have separate Spaces" **on**, so the fullscreen browser on the projector does not black out the laptop screen; "Automatically rearrange Spaces" **off**, so nothing moves between rehearsal and stage. Notifications off is already on the day-of checklist.

## Where the speech lives

Nothing is memorised and no iPad is involved. Three layers, from rehearsal to stage:

1. [`../talk/script.md`](../talk/script.md) is the full word-for-word script. It is rehearsal material — read it aloud until the transitions are yours, then leave it on the laptop as reference.
2. The deck carries 43 per-slide presenter notes (the HTML comments in `deck.md` — beat reminders and source citations, not prose). On stage, open the built deck and press `p`: Marp's presenter view opens as a second window showing current slide, next slide, notes, and a timer. Presenter window on the laptop, slide window fullscreen on the projector.
3. Paper fallback: `dist/goatmire-2026-notes.txt` is the printable notes export. Print it; a dead presenter window then costs nothing.

Alternative, per [`../talk/slides/tooling.md`](../talk/slides/tooling.md): present `dist/goatmire-2026.pptx` in Keynote or PowerPoint, whose presenter displays also carry the notes. Choose one during rehearsal and stop switching.

## The projector: one window, six tabs

```bash
make stage
```

opens a fresh Chrome window with the rehearsed tab order — the same list as the rehearsal runbook:

| Cmd+ | Tab |
|---|---|
| 1 | slide deck (`dist/goatmire-2026.html` — run `make slides` first) |
| 2 | `/rules/new` |
| 3 | `/warehouse` |
| 4 | `/diagnostics` |
| 5 | `/verify` |
| 6 | Grafana, off the primary path |

Fullscreen the window (Cmd+Ctrl+F), pin all six tabs so a stray Cmd+W cannot lose one, and every switch in the talk is a Cmd+number. Never Cmd+Tab — the app switcher flashes the desktop and whatever else is open. Slides page with PageUp/PageDown, so returning to tab 1 always resumes exactly where the deck left off.

The live-editing server (`http://localhost:8090`, linked from the dashboard topbar) is for working on the deck, not for stage — the stage tab is the built file and depends on no extra process.

## The laptop: presenter view and the confidence monitor

Beside the presenter window, the tmux session:

```bash
make stage-tmux
```

loads [`priv/tmux/goatmire.tmuxp.yaml`](../../priv/tmux/goatmire.tmuxp.yaml) — four panes the audience never sees:

- **Phoenix server** — deploy and verify log lines; when a scenario misbehaves, the reason appears here first.
- **Health watch** — `/api/health` every two seconds: interpreter, transport, fleet, engine. If Maude goes away mid-talk, this pane says so before the UI does.
- **observer_cli** — BEAM processes and message queues; during the storm this is the "the runtime itself is fine" evidence.
- **Command pane** (focused) — where Scenarios 1–5 and the storm are actually driven.

[`priv/tmux/goatmire-scenario4.yaml`](../../priv/tmux/goatmire-scenario4.yaml) is an alternate layout for the generated-rules beat only: it promotes the command line so `mix goatmire.ai` typing is legible from the back row if that beat is shown on the projector instead of the browser.

Requires `tmuxp` (`brew install tmuxp` or `pipx install tmuxp`).

## Stream Deck

Import [`priv/streamdeck/goatmire-2026.streamdeck.json`](../../priv/streamdeck/goatmire-2026.streamdeck.json) (Stream Deck app → Profile → Import). Six keys: slide previous/next (PageUp/PageDown — works in the fullscreen deck tab) and four fullscreen MP4 fallbacks for Scenarios 1–4.

The fallback buttons need two things that are code-freeze items, not defaults: `mpv` installed (`brew install mpv`) and the recorded scenario videos in `priv/obs/` — record them during the final rehearsal ("Export slides and record a video fallback" on the code-freeze checklist).

## The fallback ladder

1. Live demo in the browser tab.
2. Scenario MP4 via Stream Deck if the live beat dies.
3. The command pane: every scenario runs headless (`mix goatmire.scenario N`), and a spoken verdict from the terminal is still a real verdict.
4. If Maude itself is gone, say "unverified" — that is the talk's own rule.
