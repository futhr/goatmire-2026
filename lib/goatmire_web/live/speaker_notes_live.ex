defmodule GoatmireWeb.SpeakerNotesLive do
  @moduledoc """
  Private, text-only speaker notes synchronized with the projected deck.

  The server clock is the only slide authority. Projector navigation updates
  this view through PubSub, and tapping any note section moves every connected
  talk surface through the same `Clock.goto/1` call.
  """

  use GoatmireWeb, :live_view

  alias Goatmire.Talk
  alias Goatmire.Talk.{Clock, Controls, Deck, Script}
  alias GoatmireWeb.Presenter.CodeExamples

  @impl true
  def mount(_, %{"talk_notes_authorized" => true}, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Goatmire.PubSub, Clock.topic())

    snap = Clock.snapshot()

    {:ok,
     assign(socket,
       page_title: "Speaker notes",
       authorized?: true,
       snap: snap,
       confirm_reset: false,
       sections: Script.sections()
     ), layout: false}
  end

  def mount(_, _, socket) do
    {:ok, assign(socket, page_title: "Speaker notes", authorized?: false), layout: false}
  end

  @impl true
  def handle_info({:talk_clock, snap}, socket), do: {:noreply, assign(socket, :snap, snap)}

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event(_, _, %{assigns: %{authorized?: false}} = socket), do: {:noreply, socket}

  def handle_event("goto", %{"slide" => number}, %{assigns: %{authorized?: true}} = socket) do
    with {slide, ""} <- Integer.parse(number),
         true <- slide in 1..Deck.count() do
      snap = Clock.goto(slide)
      {:noreply, assign(socket, :snap, snap)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("nav", %{"dir" => "next"}, socket),
    do: {:noreply, clock(socket, &Clock.next/0)}

  def handle_event("nav", %{"dir" => "prev"}, socket),
    do: {:noreply, clock(socket, &Clock.prev/0)}

  def handle_event("panel", %{"panel" => panel}, socket)
      when panel in ~w(split deck_full live_full) do
    {:noreply, clock(socket, fn -> Clock.set_panel(String.to_existing_atom(panel)) end)}
  end

  def handle_event("zoom", %{"dir" => dir}, socket) when dir in ~w(in out) do
    {:noreply, clock(socket, fn -> Clock.zoom(String.to_existing_atom(dir)) end)}
  end

  def handle_event("play", _, socket), do: {:noreply, clock(socket, &Clock.play_next/0)}

  def handle_event("play_to", %{"index" => index}, socket) do
    case Integer.parse(index) do
      {target, ""} when target >= 0 -> {:noreply, clock(socket, fn -> Clock.play_to(target) end)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("run_code", _, socket) do
    if CodeExamples.example(socket.assigns.snap.slide) do
      socket =
        socket
        |> clock(fn -> Clock.set_tab(:code) end)
        |> clock(&Clock.reveal/0)

      Talk.play(:presenter, :run_code)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("pane_action", %{"step" => step}, socket) do
    pane = socket.assigns.snap.slide_tab

    case Enum.find(Controls.pane_actions(pane), fn {known, _} -> Atom.to_string(known) == step end) do
      {known, _} ->
        socket =
          socket
          |> clock(fn -> Clock.set_tab(pane) end)
          |> clock(&Clock.reveal/0)

        Talk.play(pane, known)
        {:noreply, socket}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("reset_clock", _, socket),
    do: {:noreply, clock(socket, &Clock.reset_clock/0)}

  def handle_event("ask_reset", _, socket),
    do: {:noreply, assign(socket, :confirm_reset, true)}

  def handle_event("cancel_reset", _, socket),
    do: {:noreply, assign(socket, :confirm_reset, false)}

  def handle_event("reset_talk", _, socket) do
    {:noreply,
     socket
     |> assign(:confirm_reset, false)
     |> clock(&Clock.reset/0)}
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  @impl true
  def render(%{authorized?: false} = assigns) do
    ~H"""
    <main id="speaker-notes-locked" class="speaker-notes-locked">
      <p>Speaker notes are locked.</p>
    </main>
    """
  end

  def render(assigns) do
    ~H"""
    <main
      id="speaker-notes"
      class="speaker-notes"
      phx-hook="SpeakerNotes"
      data-current-slide={@snap.slide}
    >
      <div class="speaker-notes-list">
        <button
          :for={section <- @sections}
          id={"speaker-note-#{section.number}"}
          type="button"
          phx-click="goto"
          phx-value-slide={section.number}
          class={["speaker-note", note_state(section.number, @snap.slide)]}
          aria-current={section.number == @snap.slide && "step"}
          aria-label={"Go to slide #{section.number}: #{section.title}"}
        >
          <span class="speaker-note-label">
            {String.pad_leading(Integer.to_string(section.number), 2, "0")} — {section.title}
          </span>
          <span :for={paragraph <- section.paragraphs} class="speaker-note-paragraph">
            {paragraph}
          </span>
        </button>
      </div>
      <p class="speaker-notes-connection" role="alert">Reconnecting…</p>

      <% {_scripted?, steps, actions} =
        Controls.dock_items(@snap.slide, @snap.slide_tab, @snap.play_done)

      has_code = CodeExamples.example(@snap.slide) != nil %>
      <nav id="speaker-controls" class="speaker-controls" aria-label="Talk controls">
        <div class="speaker-controls-core">
          <button
            id="speaker-prev"
            type="button"
            phx-click="nav"
            phx-value-dir="prev"
            aria-label="Previous slide"
            title="Previous slide"
          >
            <.control_icon name={:prev} />
          </button>
          <button
            id="speaker-next"
            type="button"
            phx-click="nav"
            phx-value-dir="next"
            aria-label="Next slide"
            title="Next slide"
          >
            <.control_icon name={:next} />
          </button>
          <button
            id="speaker-deck-full"
            type="button"
            class={@snap.panel == :deck_full && "active"}
            phx-click="panel"
            phx-value-panel="deck_full"
            aria-label="Show slides only"
            aria-pressed={to_string(@snap.panel == :deck_full)}
            title="Show slides only"
          >
            <.control_icon name={:deck_full} />
          </button>
          <button
            id="speaker-split"
            type="button"
            class={@snap.panel == :split && "active"}
            phx-click="panel"
            phx-value-panel="split"
            aria-label="Show split view"
            aria-pressed={to_string(@snap.panel == :split)}
            title="Show split view"
          >
            <.control_icon name={:split} />
          </button>
          <button
            id="speaker-live-full"
            type="button"
            class={@snap.panel == :live_full && "active"}
            phx-click="panel"
            phx-value-panel="live_full"
            aria-label="Show live panel only"
            aria-pressed={to_string(@snap.panel == :live_full)}
            title="Show live panel only"
          >
            <.control_icon name={:live_full} />
          </button>
          <button
            id="speaker-zoom-out"
            type="button"
            phx-click="zoom"
            phx-value-dir="out"
            aria-label="Smaller presentation text"
            title="Smaller presentation text"
          >
            <.control_icon name={:zoom_out} />
          </button>
          <button
            id="speaker-zoom-in"
            type="button"
            phx-click="zoom"
            phx-value-dir="in"
            aria-label="Larger presentation text"
            title="Larger presentation text"
          >
            <.control_icon name={:zoom_in} />
          </button>
          <button
            id="speaker-reset-clock"
            type="button"
            class={(@snap.slide_overtime_s > 0 or @snap.drift_s > 10) && "over"}
            phx-click="reset_clock"
            aria-label={timer_label(@snap)}
            title="Restart timer"
          >
            <.control_icon name={:timer_reset} />
          </button>

          <button
            :if={!@confirm_reset}
            id="speaker-ask-reset"
            type="button"
            phx-click="ask_reset"
            aria-label="Reset talk"
            title="Reset talk"
          >
            <.control_icon name={:reset} />
          </button>
          <button
            :if={@confirm_reset}
            id="speaker-cancel-reset"
            type="button"
            class="cancel"
            phx-click="cancel_reset"
            aria-label="Cancel reset"
            title="Cancel reset"
          >
            <.control_icon name={:cancel} />
          </button>
          <button
            :if={@confirm_reset}
            id="speaker-confirm-reset"
            type="button"
            class="danger"
            phx-click="reset_talk"
            aria-label="Confirm reset talk"
            title="Confirm reset talk"
          >
            <.control_icon name={:confirm} />
          </button>
        </div>

        <div
          :if={!@confirm_reset and (has_code or steps != [] or actions != [])}
          class="speaker-controls-dynamic"
          aria-label="Live actions"
        >
          <span class="speaker-controls-separator" aria-hidden="true"></span>
          <button
            :if={has_code}
            id="speaker-run-code"
            type="button"
            phx-click="run_code"
            aria-label="Evaluate this slide's code"
            title="Evaluate this slide's code"
          >
            <.control_icon name={:run_code} />
          </button>
          <button
            :for={{label, state, index} <- steps}
            id={"speaker-play-step-#{index}"}
            type="button"
            class={Atom.to_string(state)}
            phx-click={state != :done && if(state == :next, do: "play", else: "play_to")}
            phx-value-index={state == :todo && index}
            disabled={state == :done}
            aria-label={label}
            title={label}
          >
            <.control_icon name={step_icon(state)} />
          </button>
          <button
            :for={{step, label} <- actions}
            id={"speaker-pane-action-#{step}"}
            type="button"
            phx-click="pane_action"
            phx-value-step={step}
            aria-label={label}
            title={label}
          >
            <.control_icon name={action_icon(step)} />
          </button>
        </div>
      </nav>
    </main>
    """
  end

  attr :name, :atom, required: true

  defp control_icon(assigns) do
    ~H"""
    <svg class="speaker-control-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <%= case @name do %>
        <% :prev -> %>
          <path d="m14.5 5-7 7 7 7" />
        <% :next -> %>
          <path d="m9.5 5 7 7-7 7" />
        <% :deck_full -> %>
          <rect x="3" y="5" width="18" height="14" rx="2" />
          <path d="M15 5v14M5 7h8v10H5z" class="fill-soft" />
        <% :split -> %>
          <rect x="3" y="5" width="18" height="14" rx="2" />
          <path d="M12 5v14" />
        <% :live_full -> %>
          <rect x="3" y="5" width="18" height="14" rx="2" />
          <path d="M9 5v14m2-12h8v10h-8z" class="fill-soft" />
        <% :zoom_out -> %>
          <circle cx="10.5" cy="10.5" r="5.5" /><path d="m15 15 5 5M7.5 10.5h6" />
        <% :zoom_in -> %>
          <circle cx="10.5" cy="10.5" r="5.5" /><path d="m15 15 5 5M7.5 10.5h6m-3-3v6" />
        <% :timer_reset -> %>
          <circle cx="12" cy="13" r="7" /><path d="M12 10v4l3 2M9 3h6M12 3v3M5 6l2 2" />
        <% :reset -> %>
          <path d="M19 12a7 7 0 1 1-2.1-5M19 3v4.5h-4.5" />
        <% :cancel -> %>
          <path d="m6 6 12 12M18 6 6 18" />
        <% :confirm -> %>
          <path d="m5 12.5 4.5 4.5L19 7" />
        <% :play -> %>
          <path d="m9 7 9 5-9 5z" class="fill" />
        <% :done -> %>
          <path d="m5 12.5 4.5 4.5L19 7" />
        <% :queued -> %>
          <circle cx="12" cy="12" r="3" class="fill" />
        <% :run_code -> %>
          <path d="m8 7-5 5 5 5m8-10 5 5-5 5" /><path d="m10 18 4-12" />
        <% :deploy -> %>
          <path d="M12 16V5m-4 4 4-4 4 4M5 15v4h14v-4" />
        <% :load -> %>
          <path d="M3 7h7l2 2h9v10H3zM12 11v5m-2-2 2 2 2-2" />
        <% :check -> %>
          <path d="M12 3 20 6v6c0 4-3.4 7-8 9-4.6-2-8-5-8-9V6zM8 12l2.5 2.5L16 9" />
        <% :observe -> %>
          <path d="M2.5 12s3.5-5 9.5-5 9.5 5 9.5 5-3.5 5-9.5 5-9.5-5-9.5-5Z" /><circle
            cx="12"
            cy="12"
            r="2.5"
          />
        <% :enforce -> %>
          <path d="M12 3 20 6v6c0 4-3.4 7-8 9-4.6-2-8-5-8-9V6zM9 12l2 2 4-4" />
        <% :clear -> %>
          <path d="M5 7h14M9 7V4h6v3m2 0-1 13H8L7 7m3 3v7m4-7v7" />
        <% :diagnose -> %>
          <path d="M4 5h16v11H10l-5 4v-4H4zM8 10h8M8 13h5" />
        <% :verify -> %>
          <path d="M5 4h14v16H5zM8 9l2 2 4-4M8 15h8" />
        <% :notebook_reset -> %>
          <path d="M6 3h11l2 2v16H6zM9 9h7M9 13h7M4 8v8" /><path d="M3 13a3 3 0 1 0 2-2.8M3 8v3h3" />
      <% end %>
    </svg>
    """
  end

  defp step_icon(:done), do: :done
  defp step_icon(:next), do: :play
  defp step_icon(:todo), do: :queued

  defp action_icon(:seed_deployed), do: :deploy
  defp action_icon(:load_example), do: :load
  defp action_icon(:check), do: :check
  defp action_icon(:observe), do: :observe
  defp action_icon(:enforce), do: :enforce
  defp action_icon(:clear), do: :clear
  defp action_icon(:diagnose), do: :diagnose
  defp action_icon(:run_policy), do: :verify
  defp action_icon(:run_next), do: :play
  defp action_icon(:reset), do: :notebook_reset

  defp clock(socket, fun), do: assign(socket, :snap, fun.())

  defp timer_label(snap) do
    "Restart timer. Slide #{format_seconds(snap.slide_elapsed_s)} of " <>
      "#{format_seconds(snap.slide_budget_s)}; drift #{snap.drift_s} seconds"
  end

  defp format_seconds(seconds) do
    seconds = max(seconds, 0)

    padded =
      seconds
      |> rem(60)
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    "#{div(seconds, 60)}:#{padded}"
  end

  defp note_state(number, current) when number == current, do: "current"
  defp note_state(number, current) when abs(number - current) == 1, do: "adjacent"
  defp note_state(_, _), do: "distant"
end
