defmodule GoatmireWeb.PresenterLive do
  @moduledoc """
  The stage surface: deck on the left, the running system on the right.

  Every slide enters deck-only and reveals the one pane it is bound to, so
  the room reads a claim before it sees the evidence. Panes are nested
  LiveViews rather than components — a demo that crashes takes only itself
  down, and `Goatmire.Talk.Clock` holds slide, layout, and zoom so a refresh
  lands exactly where the talk was.
  """

  use GoatmireWeb, :live_view

  alias Goatmire.{Notebook, Talk}
  alias Goatmire.Talk.Clock
  alias GoatmireWeb.Presenter.{CodeExamples, Slides}

  @panes %{
    warehouse: GoatmireWeb.WarehouseLive,
    rules: GoatmireWeb.RuleLive,
    diagnostics: GoatmireWeb.DiagnosticsLive,
    verify: GoatmireWeb.VerifyLive,
    notebook: GoatmireWeb.NotebookLive,
    metrics: GoatmireWeb.MetricsLive
  }

  @impl true
  def mount(_, _, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Clock.topic())
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Talk.play_topic())
    end

    {:ok,
     socket
     |> assign(page_title: "Talk", panes: @panes)
     |> assign(snap: safe(&Clock.snapshot/0), shortcuts_open: false)
     |> assign(code_results: %{}, code_task: nil, code_slide: nil), layout: false}
  end

  @impl true
  def handle_info({:talk_clock, snap}, socket), do: {:noreply, assign(socket, :snap, snap)}

  def handle_info({:talk_play, :presenter, :run_code}, socket),
    do: {:noreply, run_code(socket)}

  def handle_info({ref, result}, %{assigns: %{code_task: %{ref: ref}}} = socket) do
    Process.demonitor(ref, [:flush])
    {:noreply, finish_code(socket, result)}
  end

  def handle_info(
        {:DOWN, ref, :process, _, reason},
        %{assigns: %{code_task: %{ref: ref}}} = socket
      ) do
    {:noreply, finish_code(socket, {:error, "card died: #{inspect(reason)}", ""})}
  end

  def handle_info({:code_timeout, ref}, %{assigns: %{code_task: %{ref: ref} = task}} = socket) do
    Task.shutdown(task, :brutal_kill)
    {:noreply, finish_code(socket, {:error, "card exceeded its deadline", ""})}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  # Code cards evaluate in a supervised task, like the notebook pane: a card
  # that raises or hangs leaves the deck and the clock untouched.
  defp run_code(%{assigns: %{code_task: nil}} = socket) do
    slide = socket.assigns.snap.slide

    case CodeExamples.example(slide) do
      nil ->
        socket

      example ->
        socket =
          socket
          |> clock(fn -> Clock.set_tab(:code) end)
          |> clock(&Clock.reveal/0)

        task =
          Task.Supervisor.async_nolink(Goatmire.TaskSupervisor, fn ->
            Notebook.eval(example.code, [])
          end)

        Process.send_after(self(), {:code_timeout, task.ref}, Notebook.eval_timeout())
        assign(socket, code_task: task, code_slide: slide)
    end
  end

  # a card is already running
  defp run_code(socket), do: socket

  defp finish_code(socket, result) do
    entry =
      case result do
        {:ok, value, _, _, output} -> %{status: :ok, value: value, output: output}
        {:error, message, output} -> %{status: :error, error: message, output: output}
      end

    assign(socket,
      code_results: Map.put(socket.assigns.code_results, socket.assigns.code_slide, entry),
      code_task: nil,
      code_slide: nil
    )
  end

  @impl true
  def handle_event(_, _, %{assigns: %{snap: nil}} = socket) do
    {:noreply, clock(socket, &Clock.snapshot/0)}
  end

  def handle_event("hide_shortcuts", _, socket),
    do: {:noreply, assign(socket, :shortcuts_open, false)}

  def handle_event("key", %{"key" => key}, %{assigns: %{shortcuts_open: true}} = socket) do
    case key do
      "Escape" -> {:noreply, assign(socket, :shortcuts_open, false)}
      "?" -> {:noreply, assign(socket, :shortcuts_open, false)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("key", %{"key" => key}, socket) do
    case keybinding(key) do
      nil ->
        {:noreply, socket}

      :play ->
        {:noreply, clock(socket, &Clock.play_next/0)}

      :toggle_shortcuts ->
        {:noreply, assign(socket, :shortcuts_open, not socket.assigns.shortcuts_open)}

      :last_slide ->
        {:noreply, clock(socket, fn -> Clock.goto(socket.assigns.snap.slide_count) end)}

      fun when is_function(fun, 0) ->
        {:noreply, clock(socket, fun)}
    end
  end

  # The stage keymap, as a table: PageUp/PageDown are what a clicker sends.
  defp keybinding(key) when key in ["ArrowRight", "PageDown", " "], do: &Clock.next/0
  defp keybinding(key) when key in ["ArrowLeft", "PageUp"], do: &Clock.prev/0
  defp keybinding(key) when key in ["+", "="], do: fn -> Clock.zoom(:in) end
  defp keybinding("-"), do: fn -> Clock.zoom(:out) end
  defp keybinding("Home"), do: fn -> Clock.goto(1) end
  defp keybinding("End"), do: :last_slide
  defp keybinding("["), do: fn -> Clock.set_panel(:deck_full) end
  defp keybinding("]"), do: &Clock.reveal/0
  defp keybinding("\\"), do: fn -> Clock.set_panel(:split) end
  defp keybinding("r"), do: &Clock.reload_timings/0
  defp keybinding("p"), do: :play
  defp keybinding("?"), do: :toggle_shortcuts
  defp keybinding(_), do: nil

  defp clock(socket, fun) do
    case safe(fun) do
      nil -> socket
      snap -> assign(socket, :snap, snap)
    end
  end

  # The clock lives in its own supervision branch; if it is mid-restart the
  # presenter renders from the last snapshot rather than crashing with it.
  defp safe(fun) do
    fun.()
  catch
    :exit, _ -> nil
  end

  defp panel_class(:deck_full), do: "deck-full"
  defp panel_class(:live_full), do: "live-full"
  defp panel_class(_), do: nil

  # A :code tab on a slide without a card falls back to metrics; the iPad also
  # omits its code action on those slides, so an empty pane is never offered.
  # Takes fields, not the snapshot: whole-map arguments would re-render these
  # template regions on every clock tick instead of only on tab/slide change.
  defp effective_tab(:code, slide) do
    if CodeExamples.example(slide), do: :code, else: :metrics
  end

  defp effective_tab(tab, _), do: tab

  @impl true
  def render(%{snap: nil} = assigns) do
    ~H"""
    <div class="presenter">
      <p class="scope banner" style="margin: 2rem">
        The talk clock is not running. It restarts on its own; reload if this persists.
      </p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div
      id="presenter"
      class={["presenter", panel_class(@snap.panel)]}
      phx-window-keydown="key"
    >
      <div class={["presenter-grid", panel_class(@snap.panel)]} style={"zoom: #{@snap.zoom}"}>
        <div class="deck-pane">
          <div id={"deck-slide-#{@snap.slide}"} class="deck-slide">
            <Slides.slide n={@snap.slide} />
          </div>
        </div>

        <div class="live-pane">
          <div class="live-pane-body">
            <div :if={effective_tab(@snap.tab, @snap.slide) == :code} class="code-card">
              <%= if example = CodeExamples.example(@snap.slide) do %>
                <div class="section-label">{example.title}</div>
                <p class="note">{example.description}</p>
                <div class="highlight">
                  <.code_block code={example.code} />
                </div>
                <span class="code-card-source">{example.source}</span>

                <div :if={result = @code_results[@snap.slide]} class="nb-output">
                  <pre :if={result.output not in [nil, ""]} class="nb-stdout">{result.output}</pre>

                  <div :if={result.status == :ok} class="highlight">
                    <.term_block term={result.value} />
                  </div>

                  <p :if={result.status == :error} class="nb-error">{result.error}</p>
                </div>
              <% end %>
            </div>

            <div
              :for={{tab, module} <- @panes}
              class={effective_tab(@snap.tab, @snap.slide) != tab && "hidden-pane"}
            >
              {live_render(@socket, module, id: "pane-#{tab}")}
            </div>
          </div>
        </div>
      </div>

      <div :if={@shortcuts_open} id="presenter-shortcuts" class="presenter-modal">
        <button
          type="button"
          class="presenter-modal-backdrop"
          phx-click="hide_shortcuts"
          aria-label="Close keyboard shortcuts"
        ></button>
        <div
          class="presenter-modal-card presenter-shortcuts-card"
          role="dialog"
          aria-modal="true"
          aria-labelledby="presenter-shortcuts-title"
        >
          <h2 id="presenter-shortcuts-title">Keyboard shortcuts</h2>
          <div class="presenter-shortcuts-grid">
            <section>
              <h3>Slides</h3>
              <dl>
                <div>
                  <dt><kbd>←</kbd> <kbd>Page Up</kbd></dt><dd>Previous</dd>
                </div>
                <div>
                  <dt><kbd>→</kbd> <kbd>Page Down</kbd> <kbd>Space</kbd></dt><dd>Next</dd>
                </div>
                <div>
                  <dt><kbd>Home</kbd> <kbd>End</kbd></dt><dd>First / last</dd>
                </div>
              </dl>
            </section>
            <section>
              <h3>Stage</h3>
              <dl>
                <div>
                  <dt><kbd>[</kbd> <kbd>\\</kbd> <kbd>]</kbd></dt><dd>Deck / split / reveal pane</dd>
                </div>
                <div>
                  <dt><kbd>p</kbd></dt><dd>Next live action</dd>
                </div>
                <div>
                  <dt><kbd>−</kbd> <kbd>+</kbd></dt><dd>Text size</dd>
                </div>
              </dl>
            </section>
            <section>
              <h3>Screen</h3>
              <dl>
                <div>
                  <dt><kbd>f</kbd></dt><dd>Fullscreen</dd>
                </div>
                <div>
                  <dt><kbd>?</kbd> <kbd>Esc</kbd></dt><dd>Help / close</dd>
                </div>
              </dl>
            </section>
            <section>
              <h3>Rehearsal</h3>
              <dl>
                <div>
                  <dt><kbd>r</kbd></dt><dd>Reload timings</dd>
                </div>
              </dl>
            </section>
          </div>
          <p class="presenter-shortcuts-note">
            Touch controls live on the private speaker-notes screen. Typing in a form never drives
            the deck.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
