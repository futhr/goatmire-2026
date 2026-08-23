defmodule Goatmire.NotebookTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Goatmire.Notebook

  test "lists the stage notebooks" do
    slugs = Notebook.list()

    assert "05_agent_policy_proof" in slugs
    assert length(slugs) == 5
  end

  test "takes the title from the first heading" do
    assert Notebook.title("05_agent_policy_proof") =~ "Scenario 5"
  end

  test "splits prose and code into ordered cells" do
    cells = Notebook.cells("05_agent_policy_proof")

    assert Enum.map(cells, & &1.index) == Enum.to_list(0..(length(cells) - 1))
    assert Enum.count(cells, &(&1.type == :code)) == 8
    assert Enum.any?(cells, &(&1.type == :markdown))
    assert Enum.count(cells, & &1.setup?) == 1
    refute Enum.any?(cells, &String.starts_with?(&1.source, "# "))
    refute Enum.any?(cells, &(String.trim(&1.source) == ""))
    refute Enum.any?(cells, &String.contains?(&1.source, "```"))
  end

  test "an unknown or traversing slug yields nothing" do
    assert Notebook.cells("../../etc/passwd") == []
    assert Notebook.cells("nope") == []
    assert Notebook.list() != []
  end

  test "evaluation returns the value, the bindings, and captured output" do
    assert {:ok, 42, bindings, "hi\n"} = Notebook.eval(~s|x = 42\nIO.puts("hi")\nx|, [])
    assert bindings[:x] == 42
  end

  test "bindings accumulate across cells" do
    {:ok, _, bindings, _} = Notebook.eval("rules = [:a, :b]", [])

    assert {:ok, 2, _, _} = Notebook.eval("length(rules)", bindings)
  end

  test "a raising cell returns an error instead of escaping" do
    assert {:error, message, _} = Notebook.eval(~s|raise "boom"|, [])
    assert message == "boom"
  end

  test "a throwing cell is caught too" do
    assert {:error, message, _} = Notebook.eval("throw(:nope)", [])
    assert message =~ "nope"
  end
end
