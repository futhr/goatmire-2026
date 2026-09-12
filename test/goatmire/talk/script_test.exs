defmodule Goatmire.Talk.ScriptTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.Talk.{Clock, Controls, Deck, Script}
  alias GoatmireWeb.Presenter.CodeExamples

  setup do
    Clock.reset()
    on_exit(fn -> Clock.reset() end)
    :ok
  end

  test "the manuscript has one ordered spoken section per slide" do
    sections = Script.sections()

    assert Enum.map(sections, & &1.number) == Enum.to_list(1..Deck.count())
    assert Enum.map(sections, & &1.title) == Enum.map(Deck.titles(), &elem(&1, 1))
    assert Enum.all?(sections, &(&1.paragraphs != []))
  end

  test "the Markdown source and memorization anchors cover the live sequence" do
    source = File.read!("docs/talk/slides/deck.md")
    identities = Regex.scan(~r/<!-- slide (\d+): (.*?) -->/, source)

    assert Enum.map(identities, fn [_, n, title] -> {String.to_integer(n), title} end) ==
             Deck.titles()

    assert length(Regex.scan(~r/^---\s*$/m, source)) - 1 == Deck.count()

    anchors =
      Regex.scan(~r/^\| (\d+) \| (.*?) \| (.*?) \|$/m, File.read!("docs/talk/memorize.md"))

    assert Enum.map(anchors, fn [_, n, _, _] -> String.to_integer(n) end) ==
             Enum.to_list(1..Deck.count())

    for [_, n, anchor, _] <- anchors do
      assert hd(Script.section(String.to_integer(n)).paragraphs) == anchor
    end
  end

  test "spoken start times agree with budgets and every configured pane has content" do
    assert Clock.snapshot().warnings == []

    total =
      Enum.reduce(Deck.titles(), 0, fn {n, _}, elapsed ->
        timing = Clock.goto(n)
        [minutes, seconds] = String.split(Script.section(n).time, ":")
        assert String.to_integer(minutes) * 60 + String.to_integer(seconds) == elapsed
        if timing.slide_tab == :code, do: assert(CodeExamples.example(n))

        if timing.reveal_panel == :live_full do
          assert {pane, _} = Controls.scripted(n)
          assert pane == timing.slide_tab
        end

        elapsed + timing.slide_budget_s
      end)

    assert total == Clock.snapshot().slot_s
    assert total - 1_475 >= 300
  end

  test "the restored topics retain their narrow claims" do
    assert Enum.join(Script.section(8).paragraphs) =~ "not an unbounded proof"
    assert Enum.join(Script.section(15).paragraphs) =~ "cross-Thing"
    assert Enum.join(Script.section(20).paragraphs) =~ "exactly seven"
    assert Enum.join(Script.section(23).paragraphs) =~ "TLA+"

    assert Enum.join(Script.section(24).paragraphs) =~
             "not a claim that this demo is production proven"
  end

  test "speaker sections exclude stage directions and markdown decoration" do
    text =
      Script.sections()
      |> Enum.flat_map(& &1.paragraphs)
      |> Enum.join(" ")

    refute text =~ "*("
    refute text =~ "`"
    refute text =~ "*"
    assert text =~ "composition means"
    assert text =~ "A bad answer, a good answer, and no answer are three different things."
  end
end
