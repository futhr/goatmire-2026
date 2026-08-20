# ExMaude owns interpreter discovery, so use its health check for `:maude` tags.

maude_available? =
  try do
    match?({:ok, _}, ExMaude.version())
  rescue
    _ -> false
  catch
    :exit, _ -> false
  end

exclusions =
  [:e2e, :integration, :llm, :manual, :stress] ++
    if(maude_available?, do: [], else: [:maude])

if maude_available? do
  {:ok, version} = ExMaude.version()
  Mix.shell().info("\n  Maude #{version} reachable — verification tests included.\n")
else
  Mix.shell().info("""

    No Maude interpreter reachable — :maude tests excluded.
    Install one (`mix maude.install`) to run the verification assertions.
  """)
end

ExUnit.start(exclude: exclusions)

Application.put_env(:goatmire, :req_options,
  plug: {Req.Test, Goatmire.AI.RuleGenerator},
  retry: false
)
