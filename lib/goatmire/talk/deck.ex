defmodule Goatmire.Talk.Deck do
  @moduledoc """
  Ordered metadata for the conference deck.

  The clock, projected slides, speaker notes, and tests all take their count
  and titles from this list so a rewrite cannot leave one surface behind.
  """

  @slides [
    {1, "Zero Alert Storms"},
    {2, "Both apps were reasonable"},
    {3, "Both rules are reasonable"},
    {4, "The loop nobody designed"},
    {5, "Why wait until after deployment?"},
    {6, "Tests and checks answer different questions"},
    {7, "Four pieces"},
    {8, "Reduce is not search"},
    {9, "Four conflict categories"},
    {10, "A narrow claim can be strong"},
    {11, "Maude as an ordinary supervised dependency"},
    {12, "Verify the term the runtime executes"},
    {13, "Never turn “no answer” into “yes”"},
    {14, "Every arrow deserves a test"},
    {15, "Partition on interaction edges"},
    {16, "Catch the conflict before the rule exists"},
    {17, "Run the same shift change twice"},
    {18, "Ask the running system why"},
    {19, "An LLM may propose policy; it should not judge itself"},
    {20, "Exactly seven categories"},
    {21, "Put a deterministic gate around a probabilistic author"},
    {22, "Approval missing → clean revision → wrong jurisdiction"},
    {23, "Maude is not the only answer"},
    {24, "Keep the claim attached to its evidence"},
    {25, "Formal methods make a narrow claim strong"}
  ]

  @identity :crypto.hash(:sha256, :erlang.term_to_binary(@slides))

  @doc "Identity of the ordered deck, used to reject checkpoints from another sequence."
  @spec identity() :: binary()
  def identity, do: @identity

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
