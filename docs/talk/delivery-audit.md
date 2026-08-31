# Conference delivery audit

Date: 2026-08-20

This audit studies how Elixir and Goatmire speakers open, signpost, demonstrate, qualify, and close technical talks. It uses caption text for delivery patterns and vocabulary, not for copying subject matter.

## Method and boundary

- Every captioned video on the Goatmire International channel was included, plus twelve varied ElixirConf talks from 2018–2026.
- The current corpus contains 44 videos, 24.9 hours, and 241,175 extracted spoken tokens.
- Automatic captions are noisy, so counts are directional.
- Only source links and aggregate counts are stored here. Third-party caption text stays at its source and in temporary local files.
- Caption analysis cannot measure gaze, vocal variation, silence, gesture, slide legibility, room response, or live-demo latency.

## Corpus

### Goatmire International

1. [Goatmire Elixir 2025 — In Summary](https://www.youtube.com/watch?v=aZM0CTkOtkQ)
2. [Sonic Pi — Sam Aaron](https://www.youtube.com/watch?v=doG1uoDhQtU)
3. [State and where to find it — Benjamin Milde](https://www.youtube.com/watch?v=7Jr0Y-LI3a8)
4. [All of the cores — Lars Wikman](https://www.youtube.com/watch?v=e5iDzIsBJjQ)
5. [Turn old into new — Anita Lüdemann](https://www.youtube.com/watch?v=UY9kwf4uWPk)
6. [From Freakout to Fix — Jonatan Männchen](https://www.youtube.com/watch?v=B5Ixbr5jO4s)
7. [Who is doing the thinking? — Bruce Tate](https://www.youtube.com/watch?v=2MP1m1jZVJ0)
8. [The Umbrella and the Range — Andrea Leopardi](https://www.youtube.com/watch?v=NZZCRyghZtQ)
9. [The Oban Murders — Shannon and Parker Selbert](https://www.youtube.com/watch?v=WjxU2fBk3cY)
10. [BEAM Internals: Understanding the Erlang Scheduler — Sanne Kalkman](https://www.youtube.com/watch?v=VGFI0538H1Q)
11. [Tell me a story — Saša Jurić](https://www.youtube.com/watch?v=GOrKfCs-mr0)
12. [Branching Out with Ecto — Luís Ferreira](https://www.youtube.com/watch?v=8_R0nmtdfgs)
13. [BEAMOps in Print — Ellie Fairholm and Josep Lluis Giralt D'Lacoste](https://www.youtube.com/watch?v=owznglwRf_0)
14. [Simplicity. This is the way! — Johan Mattisson](https://www.youtube.com/watch?v=IXlUpcfthzI)
15. [Smarter Apps with Ash and MCP — Josh Price](https://www.youtube.com/watch?v=i1wVs7bgICU)
16. [Functioning Among Humans — Tobias Pfeiffer](https://www.youtube.com/watch?v=sEqDOin9bZM)
17. [From Object-Oriented to Functional Thinking — Louise Blanc](https://www.youtube.com/watch?v=w_LNzWJPiMM)
18. [Desirable Shores — Dan Janowski](https://www.youtube.com/watch?v=errBwLvP9GA)
19. [The Roots of Resiliency](https://www.youtube.com/watch?v=OPsdL46ywfk)
20. [Elixir Hot Takes — Brian Underwood](https://www.youtube.com/watch?v=pikzIelnJTY)
21. [Giocci — Hideki Takase and Kikuchi Yutaka](https://www.youtube.com/watch?v=ERsjdFiz65o)
22. [Introducing Tau5 — Sam Aaron](https://www.youtube.com/watch?v=1pB0_PU520E)
23. [A Letter From Ourselves — Zach Daniel and friends](https://www.youtube.com/watch?v=V-St2CqgWPY)
24. [Fly me a camera — Damir Batinović](https://www.youtube.com/watch?v=FWrzBOhhEhw)
25. [Power up applications with Reactor — James Harton](https://www.youtube.com/watch?v=C_IKkKG6qU4)
26. [Nerves of Vision — Alvise Susmel](https://www.youtube.com/watch?v=LQHDaqvM2ik)
27. [Small Hydro Power Plants with Elixir](https://www.youtube.com/watch?v=07ybjC7lan0)
28. [Design a hardware product with Nerves — Gus Workman](https://www.youtube.com/watch?v=VFmlNZ_BQHQ)
29. [An Elixir Savannah Modem Safari — Taun Chapman](https://www.youtube.com/watch?v=Pu5APzK3Seo)
30. [Sound the alarm — Frank Hunleth](https://www.youtube.com/watch?v=QhuULAaooRA)
31. [Overcoming my hardware phobia — Ellyse Cedeño](https://www.youtube.com/watch?v=y5WlNELKLaU)
32. [A Nerves Car — Marc Lainez](https://www.youtube.com/watch?v=jAy5_ox90n4)

### ElixirConf comparison

1. [Precision in Type System Design — José Valim, EU 2026](https://www.youtube.com/watch?v=Ay-gnCqDw9o)
2. [DurableServer — Chris McCord, EU 2026](https://www.youtube.com/watch?v=nZmDEUeHeVI)
3. [Phoenix & Ecto Made Me a Backend Engineer — Doug VonMoser, US 2025](https://www.youtube.com/watch?v=hC0qG0ovoww)
4. [Elixir's AI Future — Chris McCord, US 2025](https://www.youtube.com/watch?v=6fj2u6Vm42E)
5. [Gang of None? — José Valim, EU 2024](https://www.youtube.com/watch?v=agkXUp0hCW8)
6. [Distributed Elixir Made Simple — Johanna Larsson, EU 2025](https://www.youtube.com/watch?v=FDD_qIT1uyw)
7. [Let's talk a bit about bits and bytes — Geoffrey Lessel, US 2025](https://www.youtube.com/watch?v=l2DSBOmPOOo)
8. [Building Conversational AI with Ash AI — Jinkyou Son, US 2025](https://www.youtube.com/watch?v=g9rWEbyHTRo)
9. [A New Case for Elixir — Bruce Tate and Josh Price, US 2025](https://www.youtube.com/watch?v=Q34e3jLWYLU)
10. [Bringing Elixir to Life — José Valim, EU 2023](https://www.youtube.com/watch?v=xItzdrzY1Dc)
11. [Elixir Works Like My Brain — Andrea Leopardi, ElixirConf UY](https://www.youtube.com/watch?v=5kjd12NqqyQ)
12. [Docker and OTP: Friends or Foes? — Daniel Azuma, US 2018](https://www.youtube.com/watch?v=nLApFANtkHs)

## Quantitative pass

Rates are occurrences per thousand spoken tokens. `Audience` counts `you`, `we`, and `let's`. `Direction` counts a fixed transition vocabulary. `Demo cues` counts look/watch/notice/visible-result phrases. `Claim limits` counts explicit scope language. The manuscript parser excludes headings, stage directions, metadata, and the hard-cut map.

| Corpus | Items | Hours | Spoken tokens | Audience | Direction | Demo cues | Qualification | Claim limits |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Goatmire | 32 | 16.1 | 148,085 | 36.40 | 9.57 | 1.62 | 6.12 | 2.37 |
| ElixirConf | 12 | 8.8 | 93,090 | 40.71 | 9.84 | 2.20 | 6.75 | 2.48 |
| Current stage manuscript | 1 | — | 1,348 | 18.55 | 10.39 | 1.48 | 4.45 | 10.39 |

The manuscript row is a snapshot; rerun `scripts/analyze-conference-captions.rb` after any manuscript edit so the table matches the text being rehearsed.

The plain-language manuscript deliberately keeps necessary scope language while removing the Maude mini-language lecture, partitioning detail, detector inventories, and tool comparison from the spoken path. Its shorter sentences and smaller vocabulary are intended for live comprehension rather than written completeness.

## Patterns adopted

1. Start inside the alert storm, then introduce the machinery that resolves it. Do not repeat the host's biography.
2. Carry one verbal spine—`conflicts`, `clean`, `unverified`—through the gate, storm comparison, diagnostics, and policy check.
3. Narrate each demo as target, action, pause, result. Do not describe every click or debug live on stage.
4. Put claim limits next to the claim: simulated fleet, modelled categories, bounded snapshot, measured-on-this-machine result.
5. Use shared directional language (`we`, `you`, `now`, `let's`, `watch`) to move the room through technical transitions.
6. Put resources before the takeaways and let the narrow formal-method claim, not a URL or disclaimer, be the final sound.

These patterns produced the current 18-slide, 1,348-token manuscript with explicit recovery cuts and at least four minutes of contingency.

## What remains

The caption-text analysis is complete for this selected corpus. Performance analysis is not. The next meaningful evidence is a recorded full-speed rehearsal scored for timing, pauses, gaze, vocal contrast, slide readability, demo latency, and recovery behavior using [`docs/runbooks/rehearsal.md`](../runbooks/rehearsal.md).

To reproduce the aggregate table after obtaining the source captions in YouTube `json3` form:

```bash
ruby scripts/analyze-conference-captions.rb /path/to/json3-captions
```
