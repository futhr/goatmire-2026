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

  alias Goatmire.Talk
  alias Goatmire.Talk.{Actions, Clock, Pairing}
  alias GoatmireWeb.Presenter.{CodeExamples, PairingCode, QRCode, Slides}

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
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Pairing.topic())
    end

    {:ok,
     socket
     |> assign(page_title: "Talk", panes: @panes)
     |> assign(snap: safe(&Clock.snapshot/0), shortcuts_open: false)
     |> assign(pairing: nil, pairing_ref: nil)
     |> assign(code_results: Actions.get(:presenter)[:code_results] || %{}), layout: false}
  end

  @impl true
  def handle_info({:talk_clock, snap}, socket), do: {:noreply, assign(socket, :snap, snap)}

  def handle_info({:talk_state, :presenter, state}, socket), do: {:noreply, assign(socket, state)}

  def handle_info({:talk_action_failed, :presenter, _}, socket),
    do: {:noreply, put_flash(socket, :error, "The code card did not complete. Retry.")}

  def handle_info(:talk_paired, socket),
    do: {:noreply, assign(socket, pairing: nil, pairing_ref: nil)}

  def handle_info({:pairing_expired, ref}, %{assigns: %{pairing_ref: ref}} = socket),
    do: {:noreply, close_pairing(socket)}

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event(_, _, %{assigns: %{snap: nil}} = socket) do
    {:noreply, clock(socket, &Clock.snapshot/0)}
  end

  def handle_event("hide_shortcuts", _, socket),
    do: {:noreply, assign(socket, :shortcuts_open, false)}

  def handle_event("hide_pairing", _, socket), do: {:noreply, close_pairing(socket)}

  def handle_event("key", %{"interactive" => true}, socket), do: {:noreply, socket}

  def handle_event("key", %{"key" => key}, %{assigns: %{pairing: {_, _}}} = socket) do
    if key in ["Escape", "q"], do: {:noreply, close_pairing(socket)}, else: {:noreply, socket}
  end

  def handle_event("key", %{"key" => key}, %{assigns: %{shortcuts_open: true}} = socket) do
    case key do
      "Escape" -> {:noreply, assign(socket, :shortcuts_open, false)}
      "-" -> {:noreply, assign(socket, :shortcuts_open, false)}
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

      :pair ->
        {:noreply, open_pairing(socket)}

      :metrics ->
        {:noreply, clock(socket, fn -> toggle_metrics(socket.assigns.snap) end)}

      :last_slide ->
        {:noreply, clock(socket, fn -> Clock.goto(socket.assigns.snap.slide_count) end)}

      fun when is_function(fun, 0) ->
        {:noreply, clock(socket, fun)}
    end
  end

  # The stage keymap, as a table. Arrows navigate and PageUp/PageDown are what
  # a clicker sends. Every other key is an unshifted letter or the bottom-row
  # punctuation, so Swedish and US layouts type them the same way.
  defp keybinding(key) when key in ["ArrowRight", "PageDown", " "], do: &Clock.next/0
  defp keybinding(key) when key in ["ArrowLeft", "PageUp"], do: &Clock.prev/0
  defp keybinding("Home"), do: fn -> Clock.goto(1) end
  defp keybinding("End"), do: :last_slide
  defp keybinding("z"), do: fn -> Clock.set_panel(:deck_full) end
  defp keybinding("x"), do: fn -> Clock.set_panel(:split) end
  defp keybinding("c"), do: &Clock.reveal/0
  defp keybinding("v"), do: :play
  defp keybinding("q"), do: :pair
  defp keybinding("m"), do: :metrics
  defp keybinding(","), do: fn -> Clock.zoom(:out) end
  defp keybinding("."), do: fn -> Clock.zoom(:in) end
  defp keybinding("-"), do: :toggle_shortcuts
  defp keybinding(_), do: nil

  # Metrics opens beside the slide; pressing m again returns to slides only.
  defp toggle_metrics(%{tab: :metrics, panel: panel}) when panel != :deck_full,
    do: Clock.set_panel(:deck_full)

  defp toggle_metrics(_) do
    Clock.set_tab(:metrics)
    Clock.set_panel(:split)
  end

  # The timer carries a ref so an expiry from an earlier overlay cannot close
  # the one on screen now.
  defp open_pairing(socket) do
    ref = make_ref()
    Process.send_after(self(), {:pairing_expired, ref}, Pairing.ttl_ms())
    assign(socket, pairing: PairingCode.start(), pairing_ref: ref)
  end

  defp close_pairing(socket) do
    Pairing.revoke()
    assign(socket, pairing: nil, pairing_ref: nil)
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
              {live_render(@socket, module, id: "pane-#{tab}", session: @stage_session)}
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
                  <dt><kbd>z</kbd> <kbd>x</kbd> <kbd>c</kbd></dt><dd>Slides / split / reveal pane</dd>
                </div>
                <div>
                  <dt><kbd>v</kbd></dt><dd>Next live action</dd>
                </div>
                <div>
                  <dt><kbd>,</kbd> <kbd>.</kbd></dt><dd>Text smaller / larger</dd>
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
                  <dt><kbd>m</kbd></dt><dd>Metrics / back to slides</dd>
                </div>
                <div>
                  <dt><kbd>q</kbd></dt><dd>QR for speaker notes</dd>
                </div>
                <div>
                  <dt><kbd>-</kbd> <kbd>Esc</kbd></dt><dd>Help / close</dd>
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

      <div :if={@pairing} id="presenter-pairing" class="presenter-modal">
        <button
          type="button"
          class="presenter-modal-backdrop"
          phx-click="hide_pairing"
          aria-label="Close the speaker-notes QR code"
        ></button>
        <div
          class="presenter-modal-card presenter-pairing-card"
          role="dialog"
          aria-modal="true"
          aria-labelledby="presenter-pairing-title"
        >
          <h2 id="presenter-pairing-title">Scan for speaker notes</h2>
          <%= case @pairing do %>
            <% {:ok, code} -> %>
              <QRCode.qr_code
                class="presenter-pairing-qr"
                src={code.qr}
                alt="QR code that opens the speaker notes"
              />
              <p>{code.host} · single use · {div(Pairing.ttl_ms(), 60_000)} min</p>
            <% {:error, :remote_disabled} -> %>
              <p>Remote notes are off. Start the stage server with <code>make talk-stage</code>.</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
