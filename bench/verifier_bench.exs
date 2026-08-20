alias Goatmire.{Gate, Rules}

for {key, value} <- [
      role: :notebook,
      transport: Goatmire.Transport.Local,
      metrics_enabled: false,
      vda5050_enabled: false
    ] do
  Application.put_env(:goatmire, key, value)
end

{:ok, _} = Application.ensure_all_started(:goatmire)

case Gate.health() do
  {:ok, version} -> IO.puts("Maude #{version} reachable")
  {:error, reason} -> raise "Maude is required for this benchmark: #{inspect(reason)}"
end

inputs = %{
  "research pair" => Rules.research_state_conflict_pair(),
  "40 rules / 20 interaction partitions" => Rules.fleet(20),
  "400 rules / 200 interaction partitions" => Rules.fleet(200)
}

Benchee.run(
  %{
    "partition and verify" => fn rules ->
      {:ok, verdict, stats} = Gate.verify_partitioned(rules, scenario: :benchee)
      {verdict.status, stats}
    end
  },
  inputs: inputs,
  warmup: 1,
  time: 3,
  memory_time: 0,
  reduction_time: 0,
  parallel: 1,
  print: [fast_warning: false]
)
