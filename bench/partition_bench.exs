alias Goatmire.Rules

inputs =
  for fleet_size <- [10, 100, 1_000, 3_000], into: %{} do
    rules = Rules.fleet(fleet_size) ++ Rules.clean_set()
    {"#{length(rules)} rules", rules}
  end

Benchee.run(
  %{"build conservative interaction partitions" => &Rules.partition/1},
  inputs: inputs,
  warmup: 1,
  time: 3,
  memory_time: 1,
  reduction_time: 1,
  print: [fast_warning: false]
)
