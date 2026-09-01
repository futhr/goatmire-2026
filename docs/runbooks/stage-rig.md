# Stage rig — how the talk is physically delivered

One laptop, two screens, one iPad, and one fullscreen projector tab. The rig is the merged presenter at `/talk`: deck on the left and live panes on the right, with no projected chrome. The private iPad view at `/talk/notes` carries synchronized speech blocks and the complete touch control row. The audience never sees a window switch.

Companions: [`demo-setup.md`](./demo-setup.md) for booting the system, [`rehearsal.md`](./rehearsal.md) for the practice procedure.

## Displays

Extended desktop, never mirrored. The projector gets one fullscreen Chrome window on `/talk`; the laptop screen keeps the server log. The iPad is the private manuscript and remote.

One-time macOS settings (System Settings → Desktop & Dock → Mission Control): "Displays have separate Spaces" **on**, so the fullscreen browser on the projector does not black out the laptop screen; "Automatically rearrange Spaces" **off**, so nothing moves between rehearsal and stage. Notifications off is already on the day-of checklist.

## Where the speech lives

The speech is learned as a short story, with the full wording available as a safety net:

1. [`../talk/memorize.md`](../talk/memorize.md) contains the seven-beat story, eighteen anchors, and protected lines. Drill those until they are yours (`make learn`).
2. [`../talk/manuscript.md`](../talk/manuscript.md) is the complete plain-language reference. It is recovery text, not a word-for-word memorization assignment.

The server timer starts when you leave slide 1, so the title can sit on screen while the room settles. The iPad timer icon restarts it in place; the separate reset icon uses a two-tap confirmation and clears the whole talk.

## The iPad: synchronized notes and remote

Use a private Wi-Fi network or dedicated stage router. Venue networks may block device-to-device traffic, and the remote must never be exposed to the public internet.

Start the LAN-enabled server:

```bash
make talk-stage
```

The command prints two URLs. Open the `iPad unlock` URL once in Safari. It stores an authorized session and redirects to the clean `/talk/notes` address. Then use Share → Add to Home Screen and open **Speaker Notes** from its icon for the standalone, browser-chrome-free view.

The speech area is deliberately text only. A single fixed row of large round icons sits at the bottom:

- the current slide sits near the upper third in large black text on white;
- the neighbouring text remains visible but faded;
- tapping any complete text section calls the shared clock and moves the projector;
- projector keyboard navigation moves and centres the iPad text;
- the neutral icons control slides, panel layout, text zoom, timer restart, and talk reset;
- slide-specific live actions appear in blue at the right of that same row;
- buttons never wrap and use a minimum 44-point touch target;
- only an actual lost connection shows `Reconnecting…`.

Set iPad Auto-Lock to **Never** for the talk and restore it afterwards. Lock orientation to the rehearsed position. The stage token changes every time `make talk-stage` starts; if the Home Screen view says the notes are locked, open the newly printed unlock URL again.

The iPad is optional. If it disconnects, keep presenting with the laptop keyboard; refreshing or reopening the notes restores the server's current slide.

The Marp deck (`deck.md`) is a frozen archive. It carries the speaker-note history but is not part of the rig.

## The projector: two tabs

With the server already running from `make talk-stage`, run `make talk` in another terminal. It opens fullscreen Chrome on `/talk`. Pin one more tab: Livebook (`localhost:8080`, from the support stack). It carries LIVE 04 on stage, and off stage it is the learning surface — the teaching notebooks, the scenario lab, and the "Run in Livebook" path from the GitHub README. That is the whole tab strip.

| Input | Does |
|---|---|
| `←/→`, PageUp/PageDown, space | previous / next slide |
| Home / End | first / last slide |
| `[` `\` `]` | deck only · split · reveal this slide's configured pane |
| `-` / `+` | text zoom, held across refreshes |
| `p` or the next blue iPad action | next scripted demo step |
| tapping a later blue iPad action | runs the remaining steps in order |
| `f` | enter / leave fullscreen |
| `?` | keyboard help; `?` or Escape closes it |
| `r` | reload `priv/talk/timings.exs` |

Every slide opens deck-only so the room reads the claim before the evidence, and the right panel offers only the pane that slide owns. Revealing is deliberate: press `]` or tap an iPad layout icon. The blue live actions change with the current slide and stay at the right edge of the same bottom row.

Slide state, panel, zoom, and the clock all live in the server, so a browser refresh lands exactly where you were. That is the recovery move: Cmd+R, not window juggling.

## The laptop: server terminal

One terminal beside the manuscript, running `mix phx.server`. Deploy and verify log lines appear there first when a scenario misbehaves; `mix goatmire.health` in a second pane answers "is it me or the rig" in two seconds. Scenarios 1–5 can always run headless from a shell: `mix goatmire.scenario N`.

## The fallback ladder

1. The live pane, driven by the blue iPad actions or the `p` key.
2. The command line: every scenario runs headless (`mix goatmire.scenario N`), and a spoken verdict from the terminal is still a real verdict.
3. If Maude itself is gone, say "unverified" — that is the talk's own rule.

The presenter itself is not on this ladder: its supervision tree keeps the deck and clock alive through demo crashes (chaos-tested), and a refresh restores everything.
