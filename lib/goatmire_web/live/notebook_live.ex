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
  alias Goatmire.Talk.Actions

  @default_slug "05_agent_policy_proof"

  @impl true
  def mount(_, _, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(Goatmire.PubSub, Goatmire.Talk.play_topic())

    {:ok,
     socket
     |> assign(page_title: "Notebook", notebooks: Notebook.list())
     |> restore()}
  end

  @impl true
  def handle_event("open", %{"slug" => slug}, socket), do: queue(socket, {:open, slug})

  def handle_event("run", %{"index" => index}, socket) do
    case Integer.parse(index) do
      {number, ""} when number >= 0 -> queue(socket, {:run, number})
      _ -> {:noreply, put_flash(socket, :error, "Unknown cell.")}
    end
  end

  def handle_event("run_next", _, socket), do: queue(socket, :run_next)

  def handle_event("reset", _, socket) do
    :ok = Actions.reset_notebook()
    {:noreply, restore(socket)}
  end

  @impl true
  def handle_info({:talk_state, :notebook, state}, socket), do: {:noreply, assign(socket, state)}

  def handle_info({:talk_action_failed, :notebook, _}, socket),
    do:
      {:noreply,
       socket
       |> assign(running_index: nil)
       |> put_flash(:error, "The cell did not complete. Retry or reset the notebook.")}

  def handle_info(:talk_reset, socket), do: {:noreply, restore(socket)}
  def handle_info(_, socket), do: {:noreply, socket}

  defp restore(socket) do
    state = Actions.get(:notebook)

    defaults = %{
      slug: @default_slug,
      title: Notebook.title(@default_slug),
      cells: Notebook.cells(@default_slug),
      bindings: [],
      env: Notebook.fresh_env(),
      results: %{},
      running_index: nil,
      task: nil,
      started_at: nil
    }

    assign(socket, Map.merge(defaults, state))
  end

  defp queue(socket, action) do
    case Actions.enqueue([{nil, nil, :notebook, action}]) do
      :ok ->
        {:noreply, assign(socket, running_index: -1)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "The presenter queue is full. Wait and retry.")}
    end
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

  defp label(slug),
    do:
      slug
      |> String.replace("_", " ")
      |> String.replace(~r/^0(\d) /, "\\1 · ")

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
