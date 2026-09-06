# Run with plain Elixir, as Livebook does, so notebook setup is exercised too.
repo = System.fetch_env!("LIVEBOOK_GOATMIRE_DIR")
teaching = Path.wildcard(Path.join(repo, "notebooks/*.livemd"))
stage = Path.join(repo, "priv/livebooks/05_agent_policy_proof.livemd")

for {path, limit} <- Enum.map(teaching, &{&1, :all}) ++ [{stage, 6}] do
  cells =
    Regex.scan(~r/```elixir\n(.*?)\n```/s, File.read!(path), capture: :all_but_first)
    |> List.flatten()

  selected = if limit == :all, do: cells, else: Enum.take(cells, limit)

  Enum.reduce(selected, {[], Code.env_for_eval(file: path)}, fn source, {bindings, env} ->
    {_, bindings, env} = Code.eval_quoted_with_env(Code.string_to_quoted!(source), bindings, env)
    {bindings, env}
  end)

  IO.puts("Notebook passed: #{Path.basename(path)}")
end

{:ok, %{checks: %{explicit_approval_gate: []}}} = Goatmire.VerificationDemo.run()
IO.puts("All three policy verdicts matched the expected results.")
