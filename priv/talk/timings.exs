# Per-slide budgets for the /talk presenter, reloaded live with the `r` key —
# tweak between rehearsal runs, no restart needed.
#
# {slide, seconds} or {slide, seconds, opts} with:
#   panel: :split | :deck_full | :live_full   layout used when the panel is
#                                             revealed; slides always enter
#                                             deck-only
#   tab:   the one pane this slide owns — :code, :warehouse, :rules,
#          :diagnostics, :verify, :notebook, or :metrics
#
# Slide 18 contains the close and the reserve for recovery or questions.
# Slides 1..17 must fit inside slot_seconds minus that reserve; the clock
# warns at load time when they do not.
%{
  slot_seconds: 1_800,
  slides: [
    {1, 45},
    {2, 90},
    {3, 55},
    {4, 35},
    {5, 80, tab: :code},
    {6, 80, tab: :code},
    {7, 65, tab: :code},
    {8, 65, tab: :code},
    {9, 60, tab: :code},
    {10, 70, tab: :code},
    {11, 80, tab: :code},
    {12, 60, tab: :code},
    {13, 100, panel: :live_full, tab: :rules},
    {14, 210, panel: :live_full, tab: :warehouse},
    {15, 110, panel: :live_full, tab: :diagnostics},
    {16, 90, tab: :code},
    {17, 180, panel: :live_full, tab: :notebook},
    {18, 325, tab: :metrics}
  ]
}
