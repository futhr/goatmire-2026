# Stage deck sources

The maintained stage sequence has 25 slides. [`deck.md`](./deck.md) records its
content and sources; `Goatmire.Talk.Deck` and the Phoenix slide components render
that sequence at `/talk`. The manuscript, memorization anchors, code cards,
scripted actions, and `priv/talk/timings.exs` must change together when the
sequence changes. The talk tests check their agreement.

The Marp front matter and theme remain useful source material. This repository
has no Marp export pipeline, so it does not promise a reproducible standalone
HTML, PDF, or PPTX export. The live Phoenix presenter is the stage surface.

Follow [the stage rig runbook](../../runbooks/stage-rig.md). Its embedded
notebook pane uses the running application; external Livebook is optional
study material described in [the notebook guide](../../../notebooks/README.md).
