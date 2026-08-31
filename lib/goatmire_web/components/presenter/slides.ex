defmodule GoatmireWeb.Presenter.Slides do
  @moduledoc """
  The 18-slide conference deck as Phoenix function components.

  The main path carries one idea at a time. Partitioning, detector inventories,
  tool comparisons, and production audit detail remain in the repository for
  Q&A instead of competing with the thirty-minute story.
  """

  use Phoenix.Component

  alias Goatmire.Talk.Deck

  @doc "Slide numbers and titles, in deck order, for every talk surface."
  @spec titles() :: [{pos_integer(), String.t()}]
  def titles, do: Deck.titles()

  attr :n, :integer, required: true

  @doc "Renders slide `n` of the deck."
  @spec slide(map()) :: Phoenix.LiveView.Rendered.t()
  # A dispatch table over the slides; the branch count is deck length, not
  # decision logic.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def slide(assigns) do
    case assigns.n do
      1 -> slide_1(assigns)
      2 -> slide_2(assigns)
      3 -> slide_3(assigns)
      4 -> slide_4(assigns)
      5 -> slide_5(assigns)
      6 -> slide_6(assigns)
      7 -> slide_7(assigns)
      8 -> slide_8(assigns)
      9 -> slide_9(assigns)
      10 -> slide_10(assigns)
      11 -> slide_11(assigns)
      12 -> slide_12(assigns)
      13 -> slide_13(assigns)
      14 -> slide_14(assigns)
      15 -> slide_15(assigns)
      16 -> slide_16(assigns)
      17 -> slide_17(assigns)
      18 -> slide_18(assigns)
    end
  end

  defp slide_1(assigns) do
    ~H"""
    <section class="slide slide-1 slide--title">
      <div class="sl-eyebrow">Goatmire 2026 · 30 minutes</div>
      <h1>Zero Alert Storms</h1>
      <p class="sl-lede">
        Check rules together—before reasonable rules become an unreasonable system.
      </p>
      <p class="sl-author">Tobias Bohwalli</p>
    </section>
    """
  end

  defp slide_2(assigns) do
    ~H"""
    <section class="slide slide-2 slide--default">
      <div class="sl-eyebrow">A published SOTERIA interaction</div>
      <h1>Two reasonable rules disagree</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <div class="sl-label">O3 shape</div>
          <h2>Contact opens</h2>
          <p>Set <code>switch</code> to <code>on</code>.</p>
        </div>
        <div class="sl-panel">
          <div class="sl-label">O4 shape</div>
          <h2>Contact opens</h2>
          <p>Set <code>switch</code> to <code>off</code>.</p>
        </div>
      </div>
      <p class="sl-small">Published pattern · controlled reproduction · no real home involved</p>
    </section>
    """
  end

  defp slide_3(assigns) do
    ~H"""
    <section class="slide slide-3 slide--default">
      <div class="sl-eyebrow">Composition is the bug</div>
      <h1>The system runs the set</h1>
      <div class="sl-flow">
        <div class="sl-node">contact opens</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">switch on</div>
        <div class="sl-arrow">↔</div>
        <div class="sl-node">switch off</div>
      </div>
      <blockquote>You review one change. The system runs all of them together.</blockquote>
    </section>
    """
  end

  defp slide_4(assigns) do
    ~H"""
    <section class="slide slide-4 slide--statement">
      <div class="sl-eyebrow">The deployment question</div>
      <div class="sl-statement">If the conflict exists now, why discover it after deployment?</div>
    </section>
    """
  end

  defp slide_5(assigns) do
    ~H"""
    <section class="slide slide-5 slide--default">
      <div class="sl-eyebrow">Different tools · different questions</div>
      <h1>Tests and checks answer different questions</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <div class="sl-label">tests and simulation</div>
          <div class="sl-value">What happened in these runs?</div>
        </div>
        <div class="sl-panel">
          <div class="sl-label">formal checker</div>
          <div class="sl-value">Can these rules fight?</div>
        </div>
      </div>
      <p class="sl-lede sl-mt">A smaller question can support a stronger answer.</p>
    </section>
    """
  end

  defp slide_6(assigns) do
    ~H"""
    <section class="slide slide-6 slide--default">
      <div class="sl-eyebrow">Maude in one picture</div>
      <h1>Maude turns rules into an answer</h1>
      <div class="sl-flow">
        <div class="sl-node">validated rules</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">conflict definitions</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">answer + concrete example</div>
      </div>
      <blockquote>It checks the model we wrote—not every fact about the physical world.</blockquote>
    </section>
    """
  end

  defp slide_7(assigns) do
    ~H"""
    <section class="slide slide-7 slide--default">
      <div class="sl-eyebrow">What this demo checks</div>
      <h1>Four ways rules can fight</h1>
      <div class="sl-four">
        <div class="sl-panel">
          <div class="sl-value">opposite writes</div>
        </div>
        <div class="sl-panel">
          <div class="sl-value">opposite effects</div>
        </div>
        <div class="sl-panel">
          <div class="sl-value">chain reaction</div>
        </div>
        <div class="sl-panel">
          <div class="sl-value">state ↔ environment chain</div>
        </div>
      </div>
      <p class="sl-lede sl-mt">If a problem is not represented here, this checker does not see it.</p>
    </section>
    """
  end

  defp slide_8(assigns) do
    ~H"""
    <section class="slide slide-8 slide--default">
      <div class="sl-eyebrow">Draw the border around the answer</div>
      <h1>A narrow answer is still useful</h1>
      <div class="sl-two">
        <div class="sl-panel sl-panel--clean">
          <h2>Checked</h2>
          <p>these rules<br />these conflict definitions<br />this result</p>
        </div>
        <div class="sl-panel">
          <h2>Not checked</h2>
          <p>physics · timing · permissions · hazards we did not model</p>
        </div>
      </div>
    </section>
    """
  end

  defp slide_9(assigns) do
    ~H"""
    <section class="slide slide-9 slide--default">
      <div class="sl-eyebrow">An ordinary BEAM dependency</div>
      <h1>Maude runs as a supervised worker</h1>
      <div class="sl-flow">
        <div class="sl-node">Elixir call</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">worker pool</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">Maude process</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">typed answer</div>
      </div>
      <pre><code>ExMaude.IoT.detect_conflicts(rules)</code></pre>
    </section>
    """
  end

  defp slide_10(assigns) do
    ~H"""
    <section class="slide slide-10 slide--default">
      <div class="sl-eyebrow">One rule representation · two uses</div>
      <h1>Check the same rule you run</h1>
      <div class="sl-branch-source" phx-no-curly-interpolation>%{trigger: …, actions: …}</div>
      <div class="sl-branch-arrow"><span>↙</span><span>↘</span></div>
      <div class="sl-two">
        <div class="sl-panel sl-panel--center">checker</div>
        <div class="sl-panel sl-panel--center">runtime</div>
      </div>
      <blockquote>A checked copy that drifts from runtime checks the wrong thing.</blockquote>
    </section>
    """
  end

  defp slide_11(assigns) do
    ~H"""
    <section class="slide slide-11 slide--default">
      <div class="sl-eyebrow">The gate has three answers</div>
      <h1>Never turn “no answer” into “yes”</h1>
      <div class="sl-three">
        <div class="sl-verdict sl-verdict--clean">
          <strong>clean</strong>
          <span>check completed; no modelled conflict found</span>
        </div>
        <div class="sl-verdict sl-verdict--conflicts">
          <strong>conflicts</strong>
          <span>concrete conflict + rule ids</span>
        </div>
        <div class="sl-verdict sl-verdict--unverified">
          <strong>unverified</strong>
          <span>the checker could not answer</span>
        </div>
      </div>
    </section>
    """
  end

  defp slide_12(assigns) do
    ~H"""
    <section class="slide slide-12 slide--default">
      <div class="sl-eyebrow">The real trust boundary</div>
      <h1>Test every translation step</h1>
      <div class="sl-flow">
        <div class="sl-node">Elixir rule</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">encoded rule</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">checker output</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">deploy or stop</div>
      </div>
    </section>
    """
  end

  defp slide_13(assigns) do
    ~H"""
    <section class="slide slide-13 slide--demo">
      <div class="sl-eyebrow">Live demo · rule gate</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 01</p>
        <h1>Catch the conflict before the rule exists</h1>
        <p class="sl-live-caption">deploy rule A → check rule B → read the answer</p>
      </div>
    </section>
    """
  end

  defp slide_14(assigns) do
    ~H"""
    <section class="slide slide-14 slide--demo">
      <div class="sl-eyebrow">Live demo · warehouse floor</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 02</p>
        <h1>Run the same shift change twice</h1>
        <p class="sl-live-caption">observe → enforce · read the measured counters</p>
      </div>
    </section>
    """
  end

  defp slide_15(assigns) do
    ~H"""
    <section class="slide slide-15 slide--demo">
      <div class="sl-eyebrow">Live demo · diagnostics</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 03</p>
        <h1>Ask the running system why</h1>
        <p class="sl-live-caption">observations cite fields · inference stays separate</p>
      </div>
    </section>
    """
  end

  defp slide_16(assigns) do
    ~H"""
    <section class="slide slide-16 slide--default">
      <div class="sl-eyebrow">The same boundary works for generated policy</div>
      <h1>AI may suggest; the checker decides</h1>
      <div class="sl-flow">
        <div class="sl-node">AI suggests a rule</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">validate its shape</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">deterministic check</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">revise or admit</div>
      </div>
      <blockquote>The author does not grade its own work.</blockquote>
    </section>
    """
  end

  defp slide_17(assigns) do
    ~H"""
    <section class="slide slide-17 slide--demo">
      <div class="sl-eyebrow">Live demo · policy by hand</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 04</p>
        <h1>Approval missing → fixed → wrong region</h1>
        <p class="sl-live-caption">three inputs · three readable answers</p>
      </div>
    </section>
    """
  end

  defp slide_18(assigns) do
    ~H"""
    <section class="slide slide-18 slide--closing">
      <div class="sl-eyebrow">Thank you</div>
      <div>
        <blockquote>
          Formal methods make a narrow claim strong. They do not make a broad claim true.
        </blockquote>
        <p class="sl-small sl-mono">github.com/futhr/ex_maude · github.com/futhr/goatmire-2026</p>
      </div>
    </section>
    """
  end
end
