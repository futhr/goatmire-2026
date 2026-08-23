defmodule Goatmire.Notebook do
  @moduledoc """
  Reads a Livebook `.livemd` file as a list of prose and code cells, and
  evaluates the code cells in one accumulating binding context.

  This is not a Livebook runtime. Livebook is a CLI application, not a
  library, so the presenter renders the notebook itself and evaluates cells
  in this node — the same access an attached runtime would have. Local stage
  tooling only: a cell can reach anything the application can.
  """

  alias Goatmire.Notebook.Cell

  defmodule Cell do
    @moduledoc "One notebook cell: rendered prose, or code the presenter can run."

    @type t :: %__MODULE__{
            index: non_neg_integer(),
            type: :markdown | :code,
            source: String.t(),
            setup?: boolean()
          }

    defstruct [:index, :type, :source, setup?: false]
  end

  @dir "livebooks"
  @eval_file "notebook"
  @eval_timeout 20_000

  @doc "Notebook slugs available to the presenter, in filename order."
  @spec list() :: [String.t()]
  def list do
    case File.ls(dir()) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".livemd"))
        |> Enum.map(&Path.rootname/1)
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  @doc "Human title taken from the notebook's first heading."
  @spec title(String.t()) :: String.t()
  def title(slug) do
    case read(slug) do
      {:ok, source} ->
        source
        |> String.split("\n")
        |> Enum.find_value(slug, fn
          "# " <> heading -> String.trim(heading)
          _ -> nil
        end)

      :error ->
        slug
    end
  end

  @doc """
  Parses a notebook into ordered cells.

  Fenced `elixir` blocks become code cells; everything between them is one
  markdown cell. The title heading is dropped because the pane renders it
  separately, and the `Mix.install` guard is flagged `setup?` so the pane can
  fold it away — attached to this node it is a no-op.

  Returns `[]` when the notebook is missing.
  """
  @spec cells(String.t()) :: [Cell.t()]
  def cells(slug) do
    case read(slug) do
      {:ok, source} ->
        source
        |> split_cells()
        |> drop_title()
        |> Enum.with_index()
        |> Enum.map(&build_cell/1)

      :error ->
        []
    end
  end

  @doc """
  Evaluates `code` against `bindings` in `env`, capturing anything it prints.

  Returns `{:ok, value, bindings, env, output}` or `{:error, message, output}`.
  The environment is threaded so an `alias` in one cell still resolves in the
  next, and compile diagnostics are surfaced as the message — `CompileError`
  alone only says "cannot compile file" and logs the real reason elsewhere.

  The caller runs this inside a task so a cell that raises or loops cannot
  take the pane with it.
  """
  @spec eval(String.t(), keyword(), Macro.Env.t() | nil) ::
          {:ok, term(), keyword(), Macro.Env.t(), String.t()} | {:error, String.t(), String.t()}
  def eval(code, bindings, env \\ nil) do
    env = env || fresh_env()
    {:ok, io} = StringIO.open("")
    original = Process.group_leader()
    Process.group_leader(self(), io)

    {result, diagnostics} = Code.with_diagnostics(fn -> guarded_eval(code, bindings, env) end)

    Process.group_leader(self(), original)
    output = captured(io)
    StringIO.close(io)

    finish(result, diagnostics, output)
  end

  @doc "A fresh evaluation environment, for the first cell of a notebook."
  @spec fresh_env() :: Macro.Env.t()
  def fresh_env, do: Code.env_for_eval(file: @eval_file, line: 1)

  defp guarded_eval(code, bindings, env) do
    quoted = Code.string_to_quoted!(code, file: @eval_file)
    {value, bindings, env} = Code.eval_quoted_with_env(quoted, bindings, env)
    {:ok, value, bindings, env}
  rescue
    error -> {:error, Exception.message(error)}
  catch
    :exit, reason -> {:error, "exited: #{inspect(reason)}"}
    thrown -> {:error, "threw: #{inspect(thrown)}"}
  end

  defp finish({:ok, value, bindings, env}, diagnostics, output) do
    {:ok, value, bindings, env, output <> warnings(diagnostics)}
  end

  defp finish({:error, message}, diagnostics, output) do
    {:error, explain(message, diagnostics), output}
  end

  # CompileError's own message is a placeholder; the diagnostics carry the
  # sentence a reader needs.
  defp explain(message, diagnostics) do
    case Enum.map(diagnostics, & &1.message) do
      [] -> message
      messages -> Enum.join(messages, "\n")
    end
  end

  defp warnings([]), do: ""

  defp warnings(diagnostics) do
    diagnostics
    |> Enum.filter(&(&1.severity == :warning))
    |> Enum.map_join("", &("warning: " <> &1.message <> "\n"))
  end

  @doc "Deadline a caller should apply to `eval/2`."
  @spec eval_timeout() :: pos_integer()
  def eval_timeout, do: @eval_timeout

  defp captured(io) do
    {_, out} = StringIO.contents(io)
    out
  end

  defp build_cell({{type, source}, index}) do
    %Cell{
      index: index,
      type: type,
      source: source,
      setup?: type == :code and String.contains?(source, "Mix.install")
    }
  end

  defp drop_title([{:markdown, text} | rest]) do
    stripped =
      text
      |> String.split("\n")
      |> Enum.reject(&String.starts_with?(&1, "# "))
      |> Enum.join("\n")
      |> String.trim()

    if stripped == "", do: rest, else: [{:markdown, stripped} | rest]
  end

  defp drop_title(cells), do: cells

  # Walks the file line by line rather than splitting on a fence regex, so a
  # fence inside prose cannot swallow the rest of the notebook.
  defp split_cells(source) do
    source
    |> String.split("\n")
    |> Enum.reduce(%{cells: [], buffer: [], in_code: false}, &take_line/2)
    |> close_buffer()
    |> Enum.reverse()
    |> Enum.reject(fn {_, text} -> String.trim(text) == "" end)
  end

  defp take_line("```elixir", %{in_code: false} = state) do
    state
    |> flush(:markdown)
    |> Map.put(:in_code, true)
  end

  defp take_line("```", %{in_code: true} = state) do
    state
    |> flush(:code)
    |> Map.put(:in_code, false)
  end

  defp take_line(line, state), do: %{state | buffer: [line | state.buffer]}

  defp flush(state, type) do
    text =
      state.buffer
      |> Enum.reverse()
      |> Enum.join("\n")

    cells = if String.trim(text) == "", do: state.cells, else: [{type, text} | state.cells]
    %{state | cells: cells, buffer: []}
  end

  defp close_buffer(state) do
    state
    |> flush(if(state.in_code, do: :code, else: :markdown))
    |> Map.fetch!(:cells)
  end

  # valid_slug?/1 admits only [a-z0-9_], so the join cannot escape dir/0.
  # sobelow_skip ["Traversal.FileModule"]
  # credo:disable-for-lines:8 OeditusCredo.Check.Security.PathTraversal
  defp read(slug) do
    with true <- valid_slug?(slug),
         path = Path.join(dir(), slug <> ".livemd"),
         {:ok, source} <- File.read(path) do
      {:ok, source}
    else
      _ -> :error
    end
  end

  defp valid_slug?(slug), do: is_binary(slug) and slug =~ ~r/^[a-z0-9_]+$/

  defp dir, do: Path.join(Application.app_dir(:goatmire, "priv"), @dir)
end
