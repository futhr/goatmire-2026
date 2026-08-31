defmodule Goatmire.Talk.Deck do
  @moduledoc """
  Ordered metadata for the conference deck.

  The clock, projected slides, speaker notes, and tests all take their count
  and titles from this list so a rewrite cannot leave one surface behind.
  """

  @slides [
    {1, "Zero Alert Storms"},
    {2, "Two reasonable rules disagree"},
    {3, "The system runs the set"},
    {4, "Why wait until after deployment?"},
    {5, "Tests and checks answer different questions"},
    {6, "Maude turns rules into an answer"},
    {7, "Four ways rules can fight"},
    {8, "A narrow answer is still useful"},
    {9, "Maude runs as a supervised worker"},
    {10, "Check the same rule you run"},
    {11, "Never turn “no answer” into “yes”"},
    {12, "Test every translation step"},
    {13, "Catch the conflict before the rule exists"},
    {14, "Run the same shift change twice"},
    {15, "Ask the running system why"},
    {16, "AI may suggest; the checker decides"},
    {17, "Approval missing → fixed → wrong region"},
    {18, "Formal methods make a narrow claim strong"}
  ]

  @doc "Slide numbers and titles in stage order."
  @spec titles() :: [{pos_integer(), String.t()}]
  def titles, do: @slides

  @doc "Number of slides in the main stage deck."
  @spec count() :: pos_integer()
  def count, do: length(@slides)

  @doc "Title for one numbered slide."
  @spec title(pos_integer()) :: String.t() | nil
  def title(number) do
    case List.keyfind(@slides, number, 0) do
      {^number, title} -> title
      nil -> nil
    end
  end
end
