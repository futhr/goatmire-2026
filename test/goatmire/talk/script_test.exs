defmodule Goatmire.Talk.ScriptTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Goatmire.Talk.{Deck, Script}

  test "the manuscript has one ordered spoken section per slide" do
    sections = Script.sections()

    assert Enum.map(sections, & &1.number) == Enum.to_list(1..Deck.count())
    assert Enum.map(sections, & &1.title) == Enum.map(Deck.titles(), &elem(&1, 1))
    assert Enum.all?(sections, &(&1.paragraphs != []))
  end

  test "speaker sections exclude stage directions and markdown decoration" do
    text = Script.sections() |> Enum.flat_map(& &1.paragraphs) |> Enum.join(" ")

    refute text =~ "*("
    refute text =~ "`"
    refute text =~ "**"
    assert text =~ "A bad answer, a good answer, and no answer are three different things."
  end
end
