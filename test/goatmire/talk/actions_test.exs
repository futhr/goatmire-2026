defmodule Goatmire.Talk.ActionsTest do
  @moduledoc false
  # Drives the shared presenter command owner, so it runs alone.
  use ExUnit.Case, async: false

  alias Goatmire.Talk
  alias Goatmire.Talk.{Actions, Clock}

  setup do
    Actions.reset()
    Phoenix.PubSub.subscribe(Goatmire.PubSub, Talk.play_topic())

    on_exit(fn ->
      Actions.reset()
      Clock.reset()
    end)

    :ok
  end

  test "a completed command publishes its pane state and leaves it readable" do
    assert :ok = Actions.enqueue([{nil, nil, :rules, :load_example}])

    assert_receive {:talk_state, :rules, %{params: params}}, 5_000
    assert %{"id" => _, "action_property" => _} = params
    assert %{params: ^params} = Actions.get(:rules)
  end

  test "commands run in the order they were queued" do
    assert :ok =
             Actions.enqueue([
               {nil, nil, :rules, :load_example},
               {nil, nil, :notebook, {:open, "03_clean_rules"}}
             ])

    assert_receive {:talk_state, :rules, _}, 5_000
    assert_receive {:talk_state, :notebook, %{slug: "03_clean_rules"}}, 20_000
  end

  test "a failing command reports its pane and abandons the rest of that slide's sequence" do
    assert :ok =
             Actions.enqueue([
               {16, {make_ref(), 0}, :rules, :no_such_step},
               {16, {make_ref(), 1}, :rules, :load_example}
             ])

    assert_receive {:talk_action_failed, :rules, reason}, 5_000
    assert reason =~ "unsupported_action"

    refute_receive {:talk_state, :rules, _}, 300
  end

  test "a failing command does not abandon another slide's queued work" do
    assert :ok =
             Actions.enqueue([
               {16, {make_ref(), 0}, :rules, :no_such_step},
               {nil, nil, :notebook, {:open, "03_clean_rules"}}
             ])

    assert_receive {:talk_action_failed, :rules, _}, 5_000
    assert_receive {:talk_state, :notebook, %{slug: "03_clean_rules"}}, 20_000
  end

  test "an unknown notebook is refused rather than opened" do
    assert :ok = Actions.enqueue([{nil, nil, :notebook, {:open, "99_not_a_notebook"}}])

    assert_receive {:talk_action_failed, :notebook, reason}, 5_000
    assert reason =~ "unknown_notebook"
    assert Actions.get(:notebook) == %{}
  end

  test "the queue refuses a burst larger than it will hold" do
    burst = for _ <- 1..40, do: {nil, nil, :rules, :load_example}

    assert {:error, :busy} = Actions.enqueue(burst)
  end

  test "reset clears shared pane state and tells every surface" do
    assert :ok = Actions.enqueue([{nil, nil, :rules, :load_example}])
    assert_receive {:talk_state, :rules, _}, 5_000

    Actions.reset()

    assert_receive :talk_reset, 5_000
    assert Actions.get(:rules) == %{}
  end

  test "resetting the notebook republishes fresh bindings and clears its slide" do
    assert :ok = Actions.enqueue([{nil, nil, :notebook, {:open, "03_clean_rules"}}])
    assert_receive {:talk_state, :notebook, %{slug: "03_clean_rules"}}, 20_000

    assert :ok = Actions.reset_notebook()

    assert_receive {:talk_state, :notebook, notebook}, 5_000
    assert notebook.results == %{}
    assert notebook.bindings == []
    refute Map.has_key?(Clock.snapshot().play_done, 22)
  end
end
