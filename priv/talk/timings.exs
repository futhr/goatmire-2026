# Rehearsal budgets for the 31-slide stage sequence. Not a stage key: restart
# the server, or call Goatmire.Talk.Clock.reload_timings/0 from IEx.
# Slides enter deck-only. Configured panes open when deliberately revealed.
# Slide 2 is the index; slides 7, 18, 22 and 27 are chapter dividers: one spoken bridge each.
# Slide 31 includes the close and recovery/question reserve.
%{
  slot_seconds: 1_800,
  slides: [
    {1, 40},
    {2, 15},
    {3, 50},
    {4, 35},
    {5, 35},
    {6, 30},
    {7, 10},
    {8, 50, tab: :code},
    {9, 45, tab: :code},
    {10, 65, tab: :code},
    {11, 50, tab: :code},
    {12, 45, tab: :code},
    {13, 45, tab: :code},
    {14, 50, tab: :code},
    {15, 65, tab: :code},
    {16, 40, tab: :code},
    {17, 60, tab: :code},
    {18, 10},
    {19, 90, panel: :live_full, tab: :rules},
    {20, 195, panel: :live_full, tab: :warehouse},
    {21, 100, panel: :live_full, tab: :diagnostics},
    {22, 10},
    {23, 45, tab: :code},
    {24, 45},
    {25, 40},
    {26, 160, panel: :live_full, tab: :notebook},
    {27, 10},
    {28, 45},
    {29, 50},
    {30, 40},
    {31, 230, tab: :metrics}
  ]
}
