defmodule Goatmire.Talk.CodeExamplesTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.Notebook
  alias Goatmire.Talk.Deck
  alias GoatmireWeb.Presenter.CodeExamples

  @tag :maude
  test "each displayed code card executes against the installed verifier" do
    for {slide, _} <- Deck.titles(), example = CodeExamples.example(slide) do
      result = Notebook.eval(example.code, [])
      assert {:ok, value, _, _, output} = result, "slide #{slide}: #{inspect(result)}"
      refute match?({:error, _}, value), "slide #{slide}: #{inspect(value)}"
      refute output =~ "warning:", "slide #{slide}: #{output}"

      if slide == 8 do
        assert {:ok, _} = value.reduction
        assert {:ok, _} = value.witness

        assert {:ok, []} =
                 ExMaude.search("TALK-CELL", "ready", "idle", max_depth: 1, max_solutions: 1)
      end
    end
  end
end
