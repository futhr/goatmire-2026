# Stage rig — how the talk is physically delivered

One laptop, two screens, one fullscreen browser tab. The rig is the merged presenter at `/talk`: deck on the left, live panes on the right, timer and controls in the floating chrome. The audience never sees a window switch.

Companions: [`demo-setup.md`](./demo-setup.md) for booting the system, [`rehearsal.md`](./rehearsal.md) for the practice procedure.

## Displays

Extended desktop, never mirrored. The projector gets one fullscreen Chrome window on `/talk`; the laptop screen is the speaker's private side: the manuscript and a terminal with the server log.

One-time macOS settings (System Settings → Desktop & Dock → Mission Control): "Displays have separate Spaces" **on**, so the fullscreen browser on the projector does not black out the laptop screen; "Automatically rearrange Spaces" **off**, so nothing moves between rehearsal and stage. Notifications off is already on the day-of checklist.

## Where the speech lives

The speech is learned, not read. Two layers:

1. [`../talk/memorize.md`](../talk/memorize.md) is the learning cut — spine, anchors, beats, exits. Drill it until the anchors are yours (`make learn`).
2. [`../talk/manuscript.md`](../talk/manuscript.md) is the word-for-word reference. Keep it open on the laptop; if you blank on stage, the current slide's anchor restarts you without looking down.

The timer lives in the presenter chrome: per-slide elapsed against budget, cumulative drift, and `ended` once the slot is spent. It starts when you leave slide 1, so the title can sit on screen while the room settles. Double-click the readout to restart the timer in place; the reset button clears the whole talk.

The Marp deck (`deck.md`) is a frozen archive. It carries the speaker-note history but is not part of the rig.

## The projector: two tabs

```bash
make talk
```

opens fullscreen Chrome on `/talk`. Pin one more tab: Livebook (`localhost:8080`, from the support stack). It carries LIVE 04 on stage, and off stage it is the learning surface — the teaching notebooks, the scenario lab, and the "Run in Livebook" path from the GitHub README. That is the whole tab strip.

| Input | Does |
|---|---|
| `←/→`, PageUp/PageDown, space | previous / next slide |
| `[` `\` `]` | deck only · split · live panel full |
| `A−` / `A+` (or `-` / `+`) | text zoom, held across refreshes |
| `p` or the LIVE pill | next scripted demo step |
| clicking a later LIVE step | runs the remaining steps in order |
| `r` | reload `priv/talk/timings.exs` |

Slide state, panel, zoom, and the clock all live in the server, so a browser refresh lands exactly where you were. That is the recovery move: Cmd+R, not window juggling.

## The laptop: server terminal

One terminal beside the manuscript, running `mix phx.server`. Deploy and verify log lines appear there first when a scenario misbehaves; `mix goatmire.health` in a second pane answers "is it me or the rig" in two seconds. Scenarios 1–5 can always run headless from a shell: `mix goatmire.scenario N`.

## The fallback ladder

1. The live pane, driven by the LIVE pill.
2. The command line: every scenario runs headless (`mix goatmire.scenario N`), and a spoken verdict from the terminal is still a real verdict.
3. If Maude itself is gone, say "unverified" — that is the talk's own rule.

The presenter itself is not on this ladder: its supervision tree keeps the deck and clock alive through demo crashes (chaos-tested), and a refresh restores everything.
