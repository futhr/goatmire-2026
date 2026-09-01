defmodule GoatmireWeb.SpeakerNotesLive do
  @moduledoc """
  Private, text-only speaker notes synchronized with the projected deck.

  The server clock is the only slide authority. Projector navigation updates
  this view through PubSub, and tapping any note section moves every connected
  talk surface through the same `Clock.goto/1` call.
  """

  use GoatmireWeb, :live_view

  alias Goatmire.Talk.{Clock, Deck, Script}

  @impl true
  def mount(_, %{"talk_notes_authorized" => true}, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Goatmire.PubSub, Clock.topic())

    snap = Clock.snapshot()

    {:ok,
     assign(socket,
       page_title: "Speaker notes",
       authorized?: true,
       slide: snap.slide,
       sections: Script.sections()
     ), layout: false}
  end

  def mount(_, _, socket) do
    {:ok, assign(socket, page_title: "Speaker notes", authorized?: false), layout: false}
  end

  @impl true
  def handle_info({:talk_clock, %{slide: slide}}, %{assigns: %{slide: slide}} = socket),
    do: {:noreply, socket}

  def handle_info({:talk_clock, %{slide: slide}}, socket),
    do: {:noreply, assign(socket, :slide, slide)}

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("goto", %{"slide" => number}, %{assigns: %{authorized?: true}} = socket) do
    with {slide, ""} <- Integer.parse(number),
         true <- slide in 1..Deck.count() do
      snap = Clock.goto(slide)
      {:noreply, assign(socket, :slide, snap.slide)}
    else
      _ -> {:noreply, socket}
    end
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
      data-current-slide={@slide}
    >
      <div class="speaker-notes-list">
        <button
          :for={section <- @sections}
          id={"speaker-note-#{section.number}"}
          type="button"
          phx-click="goto"
          phx-value-slide={section.number}
          class={["speaker-note", note_state(section.number, @slide)]}
          aria-current={section.number == @slide && "step"}
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
    </main>
    """
  end

  defp note_state(number, current) when number == current, do: "current"
  defp note_state(number, current) when abs(number - current) == 1, do: "adjacent"
  defp note_state(_, _), do: "distant"
end
