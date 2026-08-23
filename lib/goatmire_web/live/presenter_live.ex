defmodule GoatmireWeb.PresenterLive do
  use GoatmireWeb, :live_view

  alias Goatmire.Notebook
  alias Goatmire.Talk
  alias Goatmire.Talk.Clock
  alias GoatmireWeb.Presenter.{CodeExamples, Slides}

  @tabs [
    warehouse: "Warehouse",
    rules: "Rules",
    diagnostics: "Diagnostics",
    verify: "Verify",
    notebook: "Notebook",
    metrics: "Metrics"
  ]

  @panes %{
    warehouse: GoatmireWeb.WarehouseLive,
    rules: GoatmireWeb.RuleLive,
    diagnostics: GoatmireWeb.DiagnosticsLive,
    verify: GoatmireWeb.VerifyLive,
    notebook: GoatmireWeb.NotebookLive,
    metrics: GoatmireWeb.MetricsLive
  }

  # One scripted step per press, mirroring docs/talk/manuscript.md.
  @play %{
    16 =>
      {:rules,
       [
         {:seed_deployed, "Deploy rule A"},
         {:load_example, "Load rule B"},
         {:check, "Check and create"}
       ]},
    17 => {:warehouse, [{:observe, "Observe"}, {:enforce, "Enforce"}]},
    18 => {:diagnostics, [{:diagnose, "Ask"}]},
    22 =>
      {:notebook,
       [
         {:run_next, "Cell 1"},
         {:run_next, "Cell 2"},
         {:run_next, "Cell 3"},
         {:run_next, "Cell 4"}
       ]}
  }

  # Every pane delegates its actions to the dock whenever it is visible;
  # scripted slides overlay progression states on the same buttons.
  @pane_actions %{
    warehouse: [{:observe, "Observe"}, {:enforce, "Enforce"}, {:clear, "Clear"}],
    rules: [
      {:seed_deployed, "Deploy rule A"},
      {:load_example, "Load rule B"},
      {:check, "Check and create"}
    ],
    diagnostics: [{:diagnose, "Ask"}],
    verify: [{:run_policy, "Run policy checks"}],
    notebook: [{:run_next, "Run next cell"}, {:reset, "Reset"}]
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Goatmire.PubSub, Clock.topic())

    {:ok,
     socket
     |> assign(page_title: "Talk", tab_options: @tabs, panes: @panes)
     |> assign(snap: safe(&Clock.snapshot/0), titles: Map.new(Slides.titles()), play_done: %{})
     |> assign(confirm_reset: false, code_results: %{}, code_task: nil, code_slide: nil),
     layout: false}
  end

  @impl true
  def handle_info({:talk_clock, snap}, socket), do: {:noreply, assign(socket, :snap, snap)}

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
  defp run_code(%{assigns: %{code_task: task}} = socket) when not is_nil(task), do: socket

  defp run_code(socket) do
    slide = socket.assigns.snap.slide

    case CodeExamples.example(slide) do
      nil ->
        socket

      example ->
        socket = socket |> clock(fn -> Clock.set_tab(:code) end) |> clock(&Clock.reveal/0)

        task =
          Task.Supervisor.async_nolink(Goatmire.TaskSupervisor, fn ->
            Notebook.eval(example.code, [])
          end)

        Process.send_after(self(), {:code_timeout, task.ref}, Notebook.eval_timeout())
        assign(socket, code_task: task, code_slide: slide)
    end
  end

  defp finish_code(socket, result) do
    entry =
      case result do
        {:ok, value, _bindings, _env, output} -> %{status: :ok, value: value, output: output}
        {:error, message, output} -> %{status: :error, error: message, output: output}
      end

    assign(socket,
      code_results: Map.put(socket.assigns.code_results, socket.assigns.code_slide, entry),
      code_task: nil,
      code_slide: nil
    )
  end

  @impl true
  def handle_event(_event, _params, %{assigns: %{snap: nil}} = socket) do
    {:noreply, clock(socket, &Clock.snapshot/0)}
  end

  def handle_event("nav", %{"dir" => "next"}, socket),
    do: {:noreply, clock(socket, &Clock.next/0)}

  def handle_event("nav", %{"dir" => "prev"}, socket),
    do: {:noreply, clock(socket, &Clock.prev/0)}

  def handle_event("panel", %{"panel" => panel}, socket)
      when panel in ~w(split deck_full live_full) do
    {:noreply, clock(socket, fn -> Clock.set_panel(String.to_existing_atom(panel)) end)}
  end

  def handle_event("tab", %{"tab" => tab}, socket) do
    with {:ok, tab} <- known_tab(tab) do
      {:noreply, socket |> clock(fn -> Clock.set_tab(tab) end) |> clock(&Clock.reveal/0)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("zoom", %{"dir" => dir}, socket) when dir in ~w(in out) do
    {:noreply, clock(socket, fn -> Clock.zoom(String.to_existing_atom(dir)) end)}
  end

  def handle_event("play", _, socket), do: {:noreply, play_step(socket)}

  def handle_event("pane_action", %{"step" => "run_code"}, socket),
    do: {:noreply, run_code(socket)}

  def handle_event("pane_action", %{"step" => step}, socket) do
    socket = clock(socket, &Clock.reveal/0)
    tab = effective_tab(socket.assigns.snap.tab, socket.assigns.snap.slide)

    case Enum.find(Map.get(@pane_actions, tab, []), fn {s, _} -> Atom.to_string(s) == step end) do
      {s, _label} -> Talk.play(tab, s)
      nil -> :ok
    end

    {:noreply, socket}
  end

  def handle_event("run_code", _, socket), do: {:noreply, run_code(socket)}

  def handle_event("play_to", %{"index" => index}, socket) do
    {:noreply, play_to(socket, String.to_integer(index))}
  end

  def handle_event("ask_reset", _, socket), do: {:noreply, assign(socket, :confirm_reset, true)}

  def handle_event("cancel_reset", _, socket),
    do: {:noreply, assign(socket, :confirm_reset, false)}

  def handle_event("reset_talk", _, socket) do
    {:noreply,
     socket
     |> assign(play_done: %{}, confirm_reset: false)
     |> clock(&Clock.reset/0)}
  end

  def handle_event("reset_clock", _, socket) do
    {:noreply, clock(socket, &Clock.reset_clock/0)}
  end

  def handle_event("key", %{"key" => key}, %{assigns: %{confirm_reset: true}} = socket) do
    case key do
      "Escape" -> {:noreply, assign(socket, :confirm_reset, false)}
      "Enter" -> handle_event("reset_talk", %{}, socket)
      _ -> {:noreply, socket}
    end
  end

  def handle_event("key", %{"key" => key}, socket) do
    case key do
      k when k in ["ArrowRight", "PageDown", " "] -> {:noreply, clock(socket, &Clock.next/0)}
      k when k in ["ArrowLeft", "PageUp"] -> {:noreply, clock(socket, &Clock.prev/0)}
      "Home" -> {:noreply, clock(socket, fn -> Clock.goto(1) end)}
      "End" -> {:noreply, clock(socket, fn -> Clock.goto(socket.assigns.snap.slide_count) end)}
      "[" -> {:noreply, clock(socket, fn -> Clock.set_panel(:deck_full) end)}
      "]" -> {:noreply, clock(socket, &Clock.reveal/0)}
      "\\" -> {:noreply, clock(socket, fn -> Clock.set_panel(:split) end)}
      k when k in ["+", "="] -> {:noreply, clock(socket, fn -> Clock.zoom(:in) end)}
      "-" -> {:noreply, clock(socket, fn -> Clock.zoom(:out) end)}
      "r" -> {:noreply, clock(socket, &Clock.reload_timings/0)}
      "p" -> {:noreply, play_step(socket)}
      _ -> {:noreply, socket}
    end
  end

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

  defp play_step(socket) do
    slide = socket.assigns.snap.slide
    play_to(socket, Map.get(socket.assigns.play_done, slide, 0))
  end

  # Clicking a later step runs every remaining step up to it, in script order.
  # Each pane processes its PubSub messages sequentially, so the choreography
  # holds even when the presenter jumps ahead.
  defp play_to(socket, target) do
    slide = socket.assigns.snap.slide

    with {pane, steps} <- Map.get(@play, slide),
         done = Map.get(socket.assigns.play_done, slide, 0),
         true <- target >= done and target < length(steps) do
      Enum.each(done..target, fn index ->
        {step, _label} = Enum.at(steps, index)
        Talk.play(pane, step)
      end)

      socket
      |> clock(fn -> Clock.set_tab(pane) end)
      |> clock(&Clock.reveal/0)
      |> assign(:play_done, Map.put(socket.assigns.play_done, slide, target + 1))
    else
      _ -> socket
    end
  end

  defp play_steps(slide, play_done) do
    case Map.get(@play, slide) do
      nil ->
        []

      {_pane, steps} ->
        done = Map.get(play_done, slide, 0)

        steps
        |> Enum.with_index()
        |> Enum.map(fn {{_step, label}, index} ->
          state =
            cond do
              index < done -> :done
              index == done -> :next
              true -> :todo
            end

          {label, state, index}
        end)
    end
  end

  # Scripted steps for the slide's pane, plus the visible pane's remaining
  # actions as plain buttons. Returns {scripted?, steps, actions}.
  defp dock_items(slide, tab, play_done) do
    case Map.get(@play, slide) do
      {pane, steps} when pane == tab ->
        covered = steps |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

        actions =
          for {step, label} <- Map.get(@pane_actions, tab, []), step not in covered do
            {label, step}
          end

        {true, play_steps(slide, play_done), actions}

      _ ->
        actions = for {step, label} <- Map.get(@pane_actions, tab, []), do: {label, step}
        {false, [], actions}
    end
  end

  defp known_tab(tab) do
    known = Keyword.keys(@tabs)

    case Enum.find(known, &(Atom.to_string(&1) == tab)) do
      nil -> :error
      tab -> {:ok, tab}
    end
  end

  defp panel_class(:deck_full), do: "deck-full"
  defp panel_class(:live_full), do: "live-full"
  defp panel_class(_), do: nil

  attr :tab, :atom, required: true

  defp tab_icon(assigns) do
    ~H"""
    <svg width="16" height="16" viewBox="0 0 20 20" fill="none" aria-hidden="true">
      <%= case @tab do %>
        <% :code -> %>
          <path
            d="M7 6 3 10l4 4M13 6l4 4-4 4"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        <% :warehouse -> %>
          <path
            d="M3 8.5 10 4l7 4.5V16H3V8.5ZM8 16v-4h4v4"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        <% :rules -> %>
          <path
            d="M10 3l6 2v5c0 3.4-2.6 5.8-6 7-3.4-1.2-6-3.6-6-7V5l6-2Z"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linejoin="round"
          />
        <% :diagnostics -> %>
          <path
            d="M4 5h12v8h-6l-3.5 3v-3H4V5Z"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        <% :verify -> %>
          <path
            d="M10 17a7 7 0 1 0 0-14 7 7 0 0 0 0 14Zm-3-7 2 2 4-4"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        <% :notebook -> %>
          <path
            d="M5 4h9l2 2v10H5zM8 8h5M8 11h5"
            stroke="currentColor"
            stroke-width="1.7"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        <% :metrics -> %>
          <path
            d="M5 16v-6m5 6V4m5 12v-8"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
          />
      <% end %>
    </svg>
    """
  end

  attr :name, :atom, required: true

  defp chrome_icon(assigns) do
    ~H"""
    <svg
      class="chrome-icon"
      width="15"
      height="15"
      viewBox="0 0 20 20"
      fill="none"
      aria-hidden="true"
    >
      <%= case @name do %>
        <% :prev -> %>
          <path
            d="M12 5l-5 5 5 5"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        <% :next -> %>
          <path
            d="M8 5l5 5-5 5"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        <% :play -> %>
          <path d="M7 4.8l8.5 5.2L7 15.2z" fill="currentColor" />
        <% :done -> %>
          <path
            d="M4 10.6l4 4 8-9"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        <% :deck_full -> %>
          <rect
            x="3"
            y="4.5"
            width="14"
            height="11"
            rx="1.5"
            stroke="currentColor"
            stroke-width="1.7"
          />
          <path d="M12 4.5v11" stroke="currentColor" stroke-width="1.7" />
          <path d="M4.5 6h6v8h-6z" fill="currentColor" opacity="0.35" />
        <% :split -> %>
          <rect
            x="3"
            y="4.5"
            width="14"
            height="11"
            rx="1.5"
            stroke="currentColor"
            stroke-width="1.7"
          />
          <path d="M10 4.5v11" stroke="currentColor" stroke-width="1.7" />
        <% :live_full -> %>
          <rect
            x="3"
            y="4.5"
            width="14"
            height="11"
            rx="1.5"
            stroke="currentColor"
            stroke-width="1.7"
          />
          <path d="M8 4.5v11" stroke="currentColor" stroke-width="1.7" />
          <path d="M9.5 6h6v8h-6z" fill="currentColor" opacity="0.35" />
        <% :fullscreen -> %>
          <path
            d="M4 8V4.5h3.5M16 8V4.5h-3.5M4 12v3.5h3.5M16 12v3.5h-3.5"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        <% :reset -> %>
          <path
            d="M15.5 10a5.5 5.5 0 1 1-1.7-4M15.5 3v3.4h-3.4"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        <% :warning -> %>
          <path
            d="M10 3.6l6.6 12H3.4zM10 8v3.4M10 13.6v.1"
            stroke="currentColor"
            stroke-width="1.7"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
      <% end %>
    </svg>
    """
  end

  defp format_clock(seconds) when seconds < 0, do: "−#{format_clock(-seconds)}"

  defp format_clock(seconds) do
    "#{div(seconds, 60)}:#{seconds |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")}"
  end

  defp ended?(snap), do: snap.started? and snap.talk_elapsed_s >= snap.slot_s

  defp drift_label(%{started?: false}), do: "not started"
  defp drift_label(%{drift_s: drift}) when abs(drift) <= 10, do: "on time"

  # Past three minutes of drift the schedule comparison is noise, so the chip
  # falls back to the total against the slot.
  defp drift_label(%{drift_s: drift} = snap) when abs(drift) > 180,
    do: "#{format_clock(snap.talk_elapsed_s)} / #{format_clock(snap.slot_s)}"

  defp drift_label(%{drift_s: drift}) when drift > 0, do: "+#{format_clock(drift)} behind"
  defp drift_label(%{drift_s: drift}), do: "#{format_clock(drift)} ahead"

  # A :code tab on a slide without a card falls back to metrics, and the
  # Code icon disappears from the pill — an empty pane is never offered.
  # Takes fields, not the snapshot: whole-map arguments would re-render these
  # template regions on every clock tick instead of only on tab/slide change.
  defp effective_tab(:code, slide) do
    if CodeExamples.example(slide), do: :code, else: :metrics
  end

  defp effective_tab(tab, _slide), do: tab

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
      phx-hook="IdleChrome"
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
                <div class="nb-actions code-card-actions">
                  <.run_button
                    id="run-code-card"
                    phx-click="run_code"
                    disabled={@code_task != nil}
                    label={
                      cond do
                        @code_task != nil -> "evaluating…"
                        Map.has_key?(@code_results, @snap.slide) -> "Reevaluate"
                        true -> "Evaluate"
                      end
                    }
                  />
                  <span class="code-card-source">{example.source}</span>
                </div>

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

      <% {scripted?, steps, actions} = dock_items(@snap.slide, @snap.slide_tab, @play_done)
      has_code = CodeExamples.example(@snap.slide) != nil %>
      <div
        :if={steps != [] or actions != [] or has_code or @snap.slide_tab != nil}
        class="live-tabs"
        role="toolbar"
        aria-label="Live panel"
      >
        <div
          :if={steps != [] or actions != [] or has_code}
          class="live-steps"
          role="toolbar"
          aria-label="Pane actions"
        >
          <span :if={scripted?} class="live-steps-label">LIVE</span>

          <button
            :if={has_code}
            id="run-code-dock"
            type="button"
            class="dock-icon"
            phx-click="run_code"
            disabled={@code_task != nil}
            title="Evaluate this slide's code"
            aria-label="Evaluate this slide's code"
          >
            <.chrome_icon name={:play} />
          </button>
          <%= for {label, state, index} <- steps do %>
            <button
              :if={state == :next}
              id="play-next"
              type="button"
              phx-click="play"
              title="Run this scripted step (p)"
            >
              <.chrome_icon name={:play} /> {label}
            </button>
            <button :if={state == :done} type="button" class="done" disabled>
              <.chrome_icon name={:done} /> {label}
            </button>
            <button
              :if={state == :todo}
              type="button"
              class="todo"
              phx-click="play_to"
              phx-value-index={index}
              title="Run the remaining steps up to here"
            >
              {label}
            </button>
          <% end %>
          <button
            :for={{label, step} <- actions}
            type="button"
            phx-click="pane_action"
            phx-value-step={step}
            title={label}
          >
            {label}
          </button>
        </div>

        <button
          :for={{tab, label} <- @tab_options}
          :if={tab == @snap.slide_tab}
          type="button"
          role="tab"
          aria-selected={to_string(effective_tab(@snap.tab, @snap.slide) == tab)}
          class={effective_tab(@snap.tab, @snap.slide) == tab && "active"}
          phx-click="tab"
          phx-value-tab={tab}
          title={label}
          aria-label={label}
        >
          <.tab_icon tab={tab} />
        </button>
      </div>

      <div class="presenter-chrome" role="toolbar" aria-label="Presenter controls">
        <button type="button" phx-click="nav" phx-value-dir="prev" aria-label="Previous slide">
          <.chrome_icon name={:prev} />
        </button>
        <span class="chrome-slide" title={@titles[@snap.slide]}>
          {@snap.slide} / {@snap.slide_count}
        </span>
        <button type="button" phx-click="nav" phx-value-dir="next" aria-label="Next slide">
          <.chrome_icon name={:next} />
        </button>
        <span
          id="chrome-clock"
          phx-hook="TimerReset"
          title="Double-click to restart the timer"
          class="chrome-clock"
        >
          <%= if ended?(@snap) do %>
            <span class="chrome-chip mono over">{format_clock(@snap.slot_s)} ended</span>
          <% else %>
            <span class={["chrome-chip", "mono", @snap.slide_overtime_s > 0 && "over"]}>
              {format_clock(@snap.slide_elapsed_s)} / {format_clock(@snap.slide_budget_s)}
            </span>
            <span class={["chrome-chip", "mono", @snap.drift_s > 10 && "over"]}>
              {drift_label(@snap)}
            </span>
          <% end %>
        </span>
        <span class="chrome-sep" />
        <button
          type="button"
          phx-click="panel"
          phx-value-panel="deck_full"
          title="Expand deck ([)"
          aria-label="Expand deck"
        >
          <.chrome_icon name={:deck_full} />
        </button>
        <button
          type="button"
          phx-click="panel"
          phx-value-panel="split"
          title={~S"Reset split (\)"}
          aria-label="Reset split"
        >
          <.chrome_icon name={:split} />
        </button>
        <button
          type="button"
          phx-click="panel"
          phx-value-panel="live_full"
          title="Expand live panel (])"
          aria-label="Expand live panel"
        >
          <.chrome_icon name={:live_full} />
        </button>
        <button type="button" phx-click="zoom" phx-value-dir="out" title="Smaller text (-)">
          A−
        </button>
        <button type="button" phx-click="zoom" phx-value-dir="in" title="Bigger text (+)">
          A+
        </button>
        <button
          id="chrome-fullscreen"
          type="button"
          phx-hook="Fullscreen"
          title="Fullscreen"
          aria-label="Fullscreen"
        >
          <.chrome_icon name={:fullscreen} />
        </button>
        <span
          :if={@snap.warnings != []}
          class="chrome-chip warn"
          title={Enum.join(@snap.warnings, " · ")}
        >
          <.chrome_icon name={:warning} />
        </span>
        <button
          type="button"
          phx-click="ask_reset"
          title="Reset talk"
          aria-label="Reset talk"
        >
          <.chrome_icon name={:reset} />
        </button>
      </div>

      <div :if={@confirm_reset} class="presenter-modal">
        <button
          type="button"
          class="presenter-modal-backdrop"
          phx-click="cancel_reset"
          aria-label="Cancel"
        ></button>
        <div class="presenter-modal-card" role="dialog" aria-modal="true">
          <h2>Reset the talk?</h2>
          <p>
            The clock returns to zero and the deck returns to slide 1.
            Panel layout, zoom, and any completed demo steps reset with it.
          </p>
          <div class="presenter-modal-actions">
            <button type="button" class="ghost" phx-click="cancel_reset">Cancel</button>
            <button id="confirm-reset" type="button" phx-click="reset_talk">Reset talk</button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
