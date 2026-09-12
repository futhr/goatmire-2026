# Rehearsal budgets for the 25-slide stage sequence. Reload with `r`.
# Slides enter deck-only. Configured panes open when deliberately revealed.
# Slide 25 includes the close and recovery/question reserve.
%{
  slot_seconds: 1_800,
  slides: [
    {1, 40},
    {2, 50},
    {3, 35},
    {4, 35},
    {5, 30},
    {6, 50, tab: :code},
    {7, 45, tab: :code},
    {8, 65, tab: :code},
    {9, 50, tab: :code},
    {10, 45, tab: :code},
    {11, 45, tab: :code},
    {12, 50, tab: :code},
    {13, 65, tab: :code},
    {14, 40, tab: :code},
    {15, 60, tab: :code},
    {16, 90, panel: :live_full, tab: :rules},
    {17, 195, panel: :live_full, tab: :warehouse},
    {18, 100, panel: :live_full, tab: :diagnostics},
    {19, 45, tab: :code},
    {20, 45},
    {21, 40},
    {22, 160, panel: :live_full, tab: :notebook},
    {23, 45},
    {24, 50},
    {25, 325, tab: :metrics}
  ]
}
