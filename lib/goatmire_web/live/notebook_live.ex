defmodule GoatmireWeb.NotebookLive do
  @moduledoc """
  Runs the stage notebooks inside the presenter.

  Livebook is a CLI application rather than a library, so this renders the
  `.livemd` cells itself and evaluates them in this node — the access an
  attached runtime would have. Bindings accumulate across cells in order,
  and each run happens in a supervised task so a cell that raises, throws,
  or hangs takes nothing with it.
  """

  use GoatmireWeb, :live_view

  alias Goatmire.Notebook

  @default_slug "05_agent_policy_proof"

  @impl true
  def mount(_, _, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Goatmire.Talk.play_topic())
    end

    {:ok, socket |> assign(page_title: "Notebook") |> load(@default_slug)}
  end

  @impl true
  def handle_event("open", %{"slug" => slug}, socket) do
    if socket.assigns.running_index, do: {:noreply, socket}, else: {:noreply, load(socket, slug)}
  end

  def handle_event("run", %{"index" => index}, socket) do
    {:noreply, run_cell(socket, String.to_integer(index))}
  end

  def handle_event("run_next", _, socket), do: {:noreply, run_next(socket)}

  def handle_event("reset", _, socket) do
    if socket.assigns.running_index do
      {:noreply, socket}
    else
      {:noreply, load(socket, socket.assigns.slug)}
    end
  end

  @impl true
  def handle_info({:talk_play, :notebook, :run_next}, socket), do: {:noreply, run_next(socket)}

  def handle_info({:talk_play, :notebook, :reset}, socket),
    do: {:noreply, load(socket, socket.assigns.slug)}

  def handle_info({ref, result}, %{assigns: %{task: %{ref: ref}}} = socket) do
    Process.demonitor(ref, [:flush])
    {:noreply, complete(socket, result)}
  end

  def handle_info({:DOWN, ref, :process, _, reason}, %{assigns: %{task: %{ref: ref}}} = socket) do
    {:noreply, complete(socket, {:error, "cell died: #{inspect(reason)}", ""})}
  end

  def handle_info({:cell_timeout, ref}, %{assigns: %{task: %{ref: ref} = task}} = socket) do
    Task.shutdown(task, :brutal_kill)
    {:noreply, complete(socket, {:error, "cell exceeded #{Notebook.eval_timeout()} ms", ""})}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp load(socket, slug) do
    assign(socket,
      slug: slug,
      notebooks: Notebook.list(),
      title: Notebook.title(slug),
      cells: Notebook.cells(slug),
      bindings: [],
      env: Notebook.fresh_env(),
      results: %{},
      running_index: nil,
      task: nil,
      started_at: nil
    )
  end

  defp run_next(socket) do
    next =
      socket.assigns.cells
      |> Enum.filter(&(&1.type == :code))
      |> Enum.find(&(not Map.has_key?(socket.assigns.results, &1.index)))

    if next, do: run_cell(socket, next.index), else: socket
  end

  defp run_cell(%{assigns: %{running_index: running}} = socket, _) when not is_nil(running),
    do: socket

  defp run_cell(socket, index) do
    case Enum.find(socket.assigns.cells, &(&1.index == index and &1.type == :code)) do
      nil ->
        socket

      cell ->
        bindings = socket.assigns.bindings
        env = socket.assigns.env

        task =
          Task.Supervisor.async_nolink(Goatmire.TaskSupervisor, fn ->
            Notebook.eval(cell.source, bindings, env)
          end)

        Process.send_after(self(), {:cell_timeout, task.ref}, Notebook.eval_timeout())

        assign(socket,
          running_index: index,
          task: task,
          started_at: System.monotonic_time(:millisecond)
        )
    end
  end

  defp complete(socket, result) do
    index = socket.assigns.running_index
    duration = System.monotonic_time(:millisecond) - (socket.assigns.started_at || 0)

    {entry, bindings, env} =
      case result do
        {:ok, value, bindings, env, output} ->
          {%{status: :ok, value: value, output: output, ms: duration}, bindings, env}

        {:error, message, output} ->
          {%{status: :error, error: message, output: output, ms: duration},
           socket.assigns.bindings, socket.assigns.env}
      end

    assign(socket,
      results: Map.put(socket.assigns.results, index, entry),
      bindings: bindings,
      env: env,
      running_index: nil,
      task: nil
    )
  end

  # Notebook prose is repository content, and MDEx escapes embedded HTML, so
  # the rendered markup is only what MDEx itself generated.
  # sobelow_skip ["XSS.Raw"]
  defp markdown(text) do
    case MDEx.to_html(text) do
      # credo:disable-for-next-line OeditusCredo.Check.Security.XSSVulnerability
      {:ok, html} -> Phoenix.HTML.raw(html)
      _ -> text
    end
  end

  defp label(slug), do: slug |> String.replace("_", " ") |> String.replace(~r/^0(\d) /, "\\1 · ")

  @impl true
  def render(assigns) do
    ~H"""
    <h1>{@title}</h1>
    <p class="lede">
      The stage notebook, evaluated in this node. Cells share one binding
      context and run in order, exactly as they would attached to Livebook.
    </p>

    <div class="row" style="margin-bottom:1.25rem">
      <button
        :for={slug <- @notebooks}
        type="button"
        class={if slug != @slug, do: "ghost"}
        phx-click="open"
        phx-value-slug={slug}
        disabled={@running_index != nil}
      >
        {label(slug)}
      </button>
      <button type="button" class="ghost" phx-click="reset" disabled={@running_index != nil}>
        reset bindings
      </button>
    </div>

    <div :for={cell <- @cells} class={"nb-cell nb-cell--#{cell.type}"}>
      <div :if={cell.type == :markdown} class="nb-prose">{markdown(cell.source)}</div>

      <div :if={cell.type == :code} class="card nb-code">
        <details :if={cell.setup?} class="nb-setup">
          <summary class="note">setup — a no-op while attached to this node</summary>
          <div class="highlight">
            <.code_block code={cell.source} />
          </div>
        </details>

        <div :if={not cell.setup?} class="highlight">
          <.code_block code={cell.source} />
        </div>

        <div class="nb-actions">
          <.run_button
            id={"run-cell-#{cell.index}"}
            phx-click="run"
            phx-value-index={cell.index}
            disabled={@running_index != nil}
            label={
              cond do
                @running_index == cell.index -> "evaluating…"
                Map.has_key?(@results, cell.index) -> "Reevaluate"
                true -> "Evaluate"
              end
            }
          />
          <span :if={result = @results[cell.index]} class="note">{result.ms} ms</span>
        </div>

        <div :if={result = @results[cell.index]} class="nb-output">
          <pre :if={result.output not in [nil, ""]} class="nb-stdout">{result.output}</pre>

          <div :if={result.status == :ok} class="highlight">
            <.term_block term={result.value} />
          </div>

          <p :if={result.status == :error} class="nb-error">{result.error}</p>
        </div>
      </div>
    </div>
    """
  end
end
