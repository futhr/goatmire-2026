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
    assert {:ok, 42, bindings, _env, "hi\n"} = Notebook.eval(~s|x = 42\nIO.puts("hi")\nx|, [])
    assert bindings[:x] == 42
  end

  test "bindings accumulate across cells" do
    {:ok, _, bindings, env, _} = Notebook.eval("rules = [:a, :b]", [])

    assert {:ok, 2, _, _, _} = Notebook.eval("length(rules)", bindings, env)
  end

  test "an alias in one cell still resolves in the next" do
    {:ok, _, bindings, env, _} = Notebook.eval("alias Goatmire.Rules", [])

    assert {:ok, module, _, _, _} = Notebook.eval("Rules", bindings, env)
    assert module == Goatmire.Rules
  end

  test "a raising cell returns an error instead of escaping" do
    assert {:error, message, _} = Notebook.eval(~s|raise "boom"|, [])
    assert message == "boom"
  end

  test "a throwing cell is caught too" do
    assert {:error, message, _} = Notebook.eval("throw(:nope)", [])
    assert message =~ "nope"
  end

  test "a missing binding reports the variable, not this repository's source" do
    assert {:error, message, _} = Notebook.eval("Encoder.encode_rules(gated)", [])

    assert message =~ ~s|undefined variable "gated"|
    refute message =~ "notebook.ex"
    refute message =~ "cannot compile file"
  end
end
