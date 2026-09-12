alias Goatmire.Engine.RuleEval
alias Goatmire.Rules

inputs =
  for fleet_size <- [10, 100, 1_000], into: %{} do
    rules = Rules.fleet(fleet_size)
    index = RuleEval.index(rules)

    world =
      Enum.reduce(1..fleet_size, %{}, fn n, world ->
        world
        |> RuleEval.put_reading("agv-#{n}", "battery", 18)
        |> RuleEval.put_reading("agv-#{n}", "hour", 10)
      end)

    {"#{fleet_size} Things / #{length(rules)} rules", {index, world, fleet_size}}
  end

dense_inputs =
  for count <- [200, 1_000, 2_000], into: %{} do
    rules =
      for n <- 1..count do
        %{
          id: "dense-#{n}",
          thing_id: "agv-1",
          trigger: {:always},
          actions: [{:set_prop, "agv-1", "sequence", n}]
        }
      end

    {"1 Thing / #{count} firing rules", {RuleEval.index(rules), %{}, 1}}
  end

Benchee.run(
  %{
    "evaluate one complete fleet tick" => fn {index, world, fleet_size} ->
      for n <- 1..fleet_size do
        RuleEval.evaluate(index, "agv-#{n}", world)
      end
    end
  },
  inputs: Map.merge(inputs, dense_inputs),
  warmup: 1,
  time: 3,
  memory_time: 1,
  reduction_time: 1,
  print: [fast_warning: false]
)
