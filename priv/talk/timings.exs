# Per-slide budgets for the /talk presenter, reloaded live with the `r` key —
# tweak between rehearsal runs, no restart needed.
#
# {slide, seconds} or {slide, seconds, opts} with:
#   panel: :split | :deck_full | :live_full   view state applied on slide entry
#   tab:   :code | :warehouse | :rules | :diagnostics | :verify | :metrics
#
# Slide 25 is the reserve: repo links, other projects, audience questions.
# Slides 1..24 must fit inside slot_seconds minus that reserve; the clock
# warns at load time when they do not.
%{
  slot_seconds: 1_800,
  slides: [
    {1, 40, panel: :deck_full},
    {2, 50, panel: :deck_full},
    {3, 35, panel: :deck_full},
    {4, 40, panel: :deck_full},
    {5, 35, panel: :deck_full},
    {6, 55, tab: :code},
    {7, 50, tab: :code},
    {8, 55, tab: :code},
    {9, 55, tab: :code},
    {10, 50, tab: :code},
    {11, 60, tab: :code},
    {12, 55, tab: :code},
    {13, 70, tab: :code},
    {14, 55, tab: :code},
    {15, 55, tab: :code},
    {16, 90, panel: :live_full, tab: :rules},
    {17, 180, panel: :live_full, tab: :warehouse},
    {18, 65, panel: :live_full, tab: :diagnostics},
    {19, 50, tab: :code},
    {20, 50, tab: :code},
    {21, 60, tab: :code},
    {22, 120, panel: :live_full, tab: :verify},
    {23, 60, tab: :metrics},
    {24, 65, tab: :metrics},
    {25, 300, tab: :metrics}
  ]
}
