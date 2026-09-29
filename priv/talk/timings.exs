# Rehearsal budgets for the 30-slide stage sequence. Not a stage key: restart
# the server, or call Goatmire.Talk.Clock.reload_timings/0 from IEx.
# Slides enter deck-only. Configured panes open when deliberately revealed.
# Slides 6, 17, 21 and 26 are chapter dividers: one spoken bridge each.
# Slide 30 includes the close and recovery/question reserve.
%{
  slot_seconds: 1_800,
  slides: [
    {1, 40},
    {2, 50},
    {3, 35},
    {4, 35},
    {5, 30},
    {6, 10},
    {7, 50, tab: :code},
    {8, 45, tab: :code},
    {9, 65, tab: :code},
    {10, 50, tab: :code},
    {11, 45, tab: :code},
    {12, 45, tab: :code},
    {13, 50, tab: :code},
    {14, 65, tab: :code},
    {15, 40, tab: :code},
    {16, 60, tab: :code},
    {17, 10},
    {18, 90, panel: :live_full, tab: :rules},
    {19, 195, panel: :live_full, tab: :warehouse},
    {20, 100, panel: :live_full, tab: :diagnostics},
    {21, 10},
    {22, 45, tab: :code},
    {23, 45},
    {24, 40},
    {25, 160, panel: :live_full, tab: :notebook},
    {26, 10},
    {27, 45},
    {28, 50},
    {29, 40},
    {30, 245, tab: :metrics}
  ]
}
