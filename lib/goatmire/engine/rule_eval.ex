defmodule Goatmire.Engine.RuleEval do
  @moduledoc """
  Pure evaluation of `ExMaude.IoT` rule terms against observed device state.

  The same term the gate reduces is the term this executes. No process state,
  no side effects — `evaluate/3` returns the actions and lets
  `Goatmire.Engine` decide how to perform them.
  """

  @type props :: %{optional(String.t()) => term()}
  @type world :: %{optional(String.t()) => props()}
  @type index :: %{optional(String.t()) => [map()]}

  @doc "Groups rules by the Thing they are bound to."
  @spec index([map()]) :: index()
  def index(rules), do: Enum.group_by(rules, & &1.thing_id)

  @doc """
  Evaluates every rule bound to `thing_id` against the current world.

  Returns `{fired, actions}` where `fired` is the list of rule ids that
  matched and `actions` is the flattened, ordered list of their actions. Order
  is rule order: when two rules write the same property, the last one wins at
  runtime — and that silent last-write-wins is precisely the behaviour the
  state-conflict check exists to catch before deployment.
  """
  @spec evaluate(index(), String.t(), world()) :: {[String.t()], [tuple()]}
  def evaluate(index, thing_id, world) do
    props = Map.get(world, thing_id, %{})
    env = Map.get(world, "__env__", %{})

    index
    |> Map.get(thing_id, [])
    |> Enum.reduce({[], []}, fn rule, {fired, actions} ->
      if triggered?(rule.trigger, props, env) do
        {[rule.id | fired], actions ++ rule.actions}
      else
        {fired, actions}
      end
    end)
    |> then(fn {fired, actions} -> {Enum.reverse(fired), actions} end)
  end

  @doc """
  Whether a trigger holds for the given property and environment maps.

  Mirrors the trigger sorts of the bundled `iot-rules.maude` model. A
  comparison against a property that has never been reported is false, not an
  error: an unseen sensor has not met a threshold.
  """
  @spec triggered?(tuple(), props(), props()) :: boolean()
  def triggered?({:always}, _, _), do: true
  def triggered?({:prop_eq, p, v}, props, _), do: Map.get(props, p) == v
  def triggered?({:prop_gt, p, v}, props, _), do: compare(Map.get(props, p), v, :gt)
  def triggered?({:prop_lt, p, v}, props, _), do: compare(Map.get(props, p), v, :lt)
  def triggered?({:prop_gte, p, v}, props, _), do: compare(Map.get(props, p), v, :gte)
  def triggered?({:prop_lte, p, v}, props, _), do: compare(Map.get(props, p), v, :lte)
  def triggered?({:env_eq, p, v}, _, env), do: Map.get(env, p) == v
  def triggered?({:env_gt, p, v}, _, env), do: compare(Map.get(env, p), v, :gt)
  def triggered?({:env_lt, p, v}, _, env), do: compare(Map.get(env, p), v, :lt)

  def triggered?({:and, a, b}, props, env),
    do: triggered?(a, props, env) and triggered?(b, props, env)

  def triggered?({:or, a, b}, props, env),
    do: triggered?(a, props, env) or triggered?(b, props, env)

  def triggered?({:not, a}, props, env), do: not triggered?(a, props, env)
  def triggered?(_, _, _), do: false

  @doc "Writes an observed reading into the world map."
  @spec put_reading(world(), String.t(), String.t(), term()) :: world()
  def put_reading(world, thing_id, property, value) do
    Map.update(world, thing_id, %{property => value}, &Map.put(&1, property, value))
  end

  @doc "Reads one property of one Thing."
  @spec get_reading(world(), String.t(), String.t()) :: term()
  def get_reading(world, thing_id, property) do
    world
    |> Map.get(thing_id, %{})
    |> Map.get(property)
  end

  defp compare(nil, _, _), do: false

  defp compare(actual, expected, op) when is_number(actual) and is_number(expected) do
    case op do
      :gt -> actual > expected
      :lt -> actual < expected
      :gte -> actual >= expected
      :lte -> actual <= expected
    end
  end

  defp compare(_, _, _), do: false
end
