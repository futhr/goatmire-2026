defmodule Goatmire.Talk.Deck do
  @moduledoc """
  Ordered metadata for the conference deck.

  The clock, projected slides, speaker notes, and tests all take their count
  and titles from this list so a rewrite cannot leave one surface behind.

  The deck is told in five chapters. The index slide lists them with their
  planned start, and chapters two to five open with a divider slide that
  carries the chapter title.
  """

  @chapters [
    {1, 1, "The problem"},
    {2, 6, "The gate"},
    {3, 17, "Live: IoT rules"},
    {4, 21, "Live: AI policy"},
    {5, 26, "Takeaways"}
  ]

  @slides [
    {1, "Formal Verification"},
    {2, "Both apps were reasonable"},
    {3, "Both rules are reasonable"},
    {4, "The loop nobody designed"},
    {5, "Why wait until the rule runs?"},
    {6, "The gate"},
    {7, "Tests and checks answer different questions"},
    {8, "Four pieces"},
    {9, "Reduce is not search"},
    {10, "Four conflict categories"},
    {11, "A narrow claim can be strong"},
    {12, "Maude as an ordinary supervised dependency"},
    {13, "Verify the term the runtime executes"},
    {14, "Never turn “no answer” into “yes”"},
    {15, "Every arrow deserves a test"},
    {16, "Partition on interaction edges"},
    {17, "Live: IoT rules"},
    {18, "Catch the conflict before the rule exists"},
    {19, "Run the same shift change twice"},
    {20, "Ask the running system why"},
    {21, "Live: AI policy"},
    {22, "An LLM may propose policy; it should not judge itself"},
    {23, "Exactly seven categories"},
    {24, "The model suggests. The gate decides."},
    {25, "Approval missing → clean revision → wrong jurisdiction"},
    {26, "Takeaways"},
    {27, "Maude is not the only answer"},
    {28, "Keep the claim attached to its evidence"},
    {29, "Decision model + Maude"},
    {30, "Formal methods strengthen narrow claims"}
  ]

  @words %{1 => "one", 2 => "two", 3 => "three", 4 => "four", 5 => "five"}

  @chapter_maps @chapters
                |> Enum.with_index()
                |> Enum.map(fn {{number, first, title}, index} ->
                  last =
                    case Enum.at(@chapters, index + 1) do
                      {_, next_first, _} -> next_first - 1
                      nil -> length(@slides)
                    end

                  %{
                    number: number,
                    label: "Chapter " <> Map.fetch!(@words, number),
                    title: title,
                    first_slide: first,
                    last_slide: last
                  }
                end)

  for %{first_slide: first, title: title} <- @chapter_maps, first > 1 do
    if List.keyfind(@slides, first, 0) != {first, title} do
      raise "slide #{first} must carry its chapter title"
    end
  end

  @dividers for %{first_slide: first} <- @chapter_maps, first > 1, do: first

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

  @type chapter :: %{
          number: pos_integer(),
          label: String.t(),
          title: String.t(),
          first_slide: pos_integer(),
          last_slide: pos_integer()
        }

  @doc "The five chapters in order, each with the slide range it spans."
  @spec chapters() :: [chapter()]
  def chapters, do: @chapter_maps

  @doc "The chapter a slide belongs to."
  @spec chapter(pos_integer()) :: chapter()
  def chapter(slide) when is_integer(slide) do
    Enum.find(@chapter_maps, List.first(@chapter_maps), fn chapter ->
      slide in chapter.first_slide..chapter.last_slide
    end)
  end

  @doc "Slides that open a chapter with a divider (every chapter but the first)."
  @spec dividers() :: [pos_integer()]
  def dividers, do: @dividers

  @doc "Whether a slide is a chapter divider."
  @spec divider?(pos_integer()) :: boolean()
  def divider?(slide), do: slide in @dividers
end
