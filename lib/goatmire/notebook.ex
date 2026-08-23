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
  Evaluates `code` against `bindings`, capturing anything it prints.

  Returns `{:ok, value, bindings, output}` or `{:error, message, output}`. The
  caller runs this inside a task so a cell that raises or loops cannot take
  the pane with it.
  """
  @spec eval(String.t(), keyword()) ::
          {:ok, term(), keyword(), String.t()} | {:error, String.t(), String.t()}
  def eval(code, bindings) do
    {:ok, io} = StringIO.open("")
    original = Process.group_leader()
    Process.group_leader(self(), io)

    try do
      {value, bindings} = Code.eval_string(code, bindings, __ENV__)
      {:ok, value, bindings, captured(io)}
    rescue
      error -> {:error, Exception.message(error), captured(io)}
    catch
      :exit, reason -> {:error, "exited: #{inspect(reason)}", captured(io)}
      thrown -> {:error, "threw: #{inspect(thrown)}", captured(io)}
    after
      Process.group_leader(self(), original)
      StringIO.close(io)
    end
  end

  @doc "Deadline a caller should apply to `eval/2`."
  @spec eval_timeout() :: pos_integer()
  def eval_timeout, do: @eval_timeout

  defp captured(io) do
    {_in, out} = StringIO.contents(io)
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
    |> Enum.reject(fn {_type, text} -> String.trim(text) == "" end)
  end

  defp take_line("```elixir", %{in_code: false} = state) do
    state |> flush(:markdown) |> Map.put(:in_code, true)
  end

  defp take_line("```", %{in_code: true} = state) do
    state |> flush(:code) |> Map.put(:in_code, false)
  end

  defp take_line(line, state), do: %{state | buffer: [line | state.buffer]}

  defp flush(state, type) do
    text = state.buffer |> Enum.reverse() |> Enum.join("\n")
    cells = if String.trim(text) == "", do: state.cells, else: [{type, text} | state.cells]
    %{state | cells: cells, buffer: []}
  end

  defp close_buffer(state) do
    state |> flush(if(state.in_code, do: :code, else: :markdown)) |> Map.fetch!(:cells)
  end

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
