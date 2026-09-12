defmodule Goatmire.Talk.ControlsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Goatmire.Talk.{Controls, Deck}

  describe "scripted/1" do
    test "a demo slide carries its pane and its ordered steps" do
      assert {:rules,
              [
                {:seed_deployed, "Deploy rule A"},
                {:load_example, "Load rule B"},
                {:check, "Check and create"}
              ]} = Controls.scripted(16)

      assert {:warehouse, [{:observe, _}, {:enforce, _}]} = Controls.scripted(17)
    end

    test "a slide without a demo carries nothing" do
      assert Controls.scripted(1) == nil
      assert Controls.scripted(Deck.count()) == nil
    end

    test "every scripted slide is in the deck and names a pane that has actions" do
      scripted = for n <- 1..Deck.count(), sequence = Controls.scripted(n), do: {n, sequence}

      assert scripted != []

      for {_, {pane, steps}} <- scripted do
        assert steps != []
        assert Controls.pane_actions(pane) != [], "#{pane} must be a pane with its own actions"
      end
    end

    test "an unknown pane has no actions" do
      assert Controls.pane_actions(:nonexistent) == []
      assert Controls.pane_actions(nil) == []
    end
  end

  describe "claim/3" do
    test "claims every step from the frontier through the target" do
      assert {:ok, :rules, [:seed_deployed], %{16 => 1}} = Controls.claim(16, %{}, 0)

      assert {:ok, :rules, [:seed_deployed, :load_example, :check], %{16 => 3}} =
               Controls.claim(16, %{}, 2)

      assert {:ok, :rules, [:load_example, :check], %{16 => 3}} =
               Controls.claim(16, %{16 => 1}, 2)
    end

    test "a step that is already done is never claimed again" do
      assert Controls.claim(16, %{16 => 1}, 0) == :noop
      assert Controls.claim(16, %{16 => 3}, 2) == :noop
    end

    test "a target past the last step claims nothing" do
      assert Controls.claim(16, %{}, 3) == :noop
      assert Controls.claim(17, %{}, 2) == :noop
    end

    test "an unscripted slide claims nothing" do
      assert Controls.claim(1, %{}, 0) == :noop
    end

    test "other slides' progress is carried through untouched" do
      assert {:ok, :diagnostics, [:diagnose], done} = Controls.claim(18, %{16 => 2}, 0)
      assert done == %{16 => 2, 18 => 1}
    end
  end

  describe "dock_items/3" do
    test "exactly one step is next, and scripted steps are not offered twice" do
      assert {true, steps, extras} = Controls.dock_items(16, :rules, %{16 => 1})

      assert steps == [
               {"Deploy rule A", :done, 0},
               {"Load rule B", :next, 1},
               {"Check and create", :todo, 2}
             ]

      assert extras == []
    end

    test "a pane action outside the script stays available beside it" do
      assert {true, [{"Observe", :next, 0}, {"Enforce", :todo, 1}], [{:clear, "Clear"}]} =
               Controls.dock_items(17, :warehouse, %{})
    end

    test "a finished sequence has no next step" do
      assert {true, steps, _} = Controls.dock_items(17, :warehouse, %{17 => 2})

      assert Enum.map(steps, &elem(&1, 1)) == [:done, :done]
    end

    test "a pane the slide does not script offers only its own actions" do
      assert {false, [], actions} = Controls.dock_items(16, :warehouse, %{})
      assert actions == Controls.pane_actions(:warehouse)

      assert {false, [], [{:run_policy, _}]} = Controls.dock_items(1, :verify, %{})
    end
  end
end
