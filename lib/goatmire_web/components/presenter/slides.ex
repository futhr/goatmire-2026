defmodule GoatmireWeb.Presenter.Slides do
  @moduledoc """
  The 25-slide conference sequence as Phoenix function components.

  Slide order agrees with the manuscript and Markdown source. Claims remain
  scoped to the demonstrated model, simulation, and measured run.
  """

  use Phoenix.Component

  alias Goatmire.Talk.Deck

  @doc "Slide numbers and titles, in deck order, for every talk surface."
  @spec titles() :: [{pos_integer(), String.t()}]
  def titles, do: Deck.titles()

  attr :n, :integer, required: true

  @doc "Renders slide `n` of the deck."
  @spec slide(map()) :: Phoenix.LiveView.Rendered.t()

  def slide(%{n: 1} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-1 slide--title">
      <div class="sl-eyebrow">Goatmire 2026 · 30 minutes</div>
      <h1>{Deck.title(@n)}</h1>
      <p class="sl-lede">
        Check rules together—before reasonable rules become an unreasonable system.
      </p>
      <p class="sl-author">Tobias Bohwalli</p>
    </section>
    """
  end

  def slide(%{n: 2} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-2 slide--default">
      <div class="sl-eyebrow">A published interaction</div><h1>{Deck.title(@n)}</h1>
      <div class="sl-value">SOTERIA · O3 + O4</div><p class="sl-lede sl-mt">
        The same contact-open event sets one switch to conflicting values.
      </p>
      <blockquote>
        Published pattern · controlled reproduction · no historical prevention claim
      </blockquote>
    </section>
    """
  end

  def slide(%{n: 3} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-3 slide--default">
      <div class="sl-eyebrow">A published SOTERIA interaction</div>
      <h1>{Deck.title(@n)}</h1>
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

  def slide(%{n: 4} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-4 slide--default">
      <div class="sl-eyebrow">Composition is the bug</div>
      <h1>{Deck.title(@n)}</h1>
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

  def slide(%{n: 5} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-5 slide--statement">
      <div class="sl-eyebrow">The deployment question</div>
      <div class="sl-statement">If the conflict exists now, why discover it after deployment?</div>
    </section>
    """
  end

  def slide(%{n: 6} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-6 slide--default">
      <div class="sl-eyebrow">Different tools · different questions</div>
      <h1>{Deck.title(@n)}</h1>
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

  def slide(%{n: 7} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-7 slide--default">
      <div class="sl-eyebrow">A Maude mental model</div><h1>{Deck.title(@n)}</h1>
      <div class="sl-four">
        <div class="sl-panel">
          <div class="sl-label">sorts</div><div class="sl-value">types</div>
        </div>
        <div class="sl-panel">
          <div class="sl-label">operators</div><div class="sl-value">constructors + functions</div>
        </div>
        <div class="sl-panel">
          <div class="sl-label">equations</div><div class="sl-value">simplify</div>
        </div>
        <div class="sl-panel">
          <div class="sl-label">rewrite rules</div><div class="sl-value">transition</div>
        </div>
      </div><p class="sl-lede sl-mt">Function clauses versus possible state transitions.</p>
    </section>
    """
  end

  def slide(%{n: 8} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-8 slide--default">
      <div class="sl-eyebrow">Two commands · two claims</div><h1>{Deck.title(@n)}</h1>
      <pre><code>reduce in SWITCH : toggle(toggle(on)) .
    search [1] in CELL : idle =&gt;* ready .</code></pre>
      <div class="sl-two">
        <div class="sl-panel">
          <h2>reduce</h2><p>normal form under equations</p>
        </div>
        <div class="sl-panel">
          <h2>search</h2><p>reachable witness under transitions</p>
        </div>
      </div>
      <p class="sl-small sl-mt">No witness within a bound is not an unbounded safety proof.</p>
    </section>
    """
  end

  def slide(%{n: 9} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-9 slide--default">
      <div class="sl-eyebrow">What this demo checks</div>
      <h1>{Deck.title(@n)}</h1>
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

  def slide(%{n: 10} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-10 slide--default">
      <div class="sl-eyebrow">Draw the border around the answer</div>
      <h1>{Deck.title(@n)}</h1>
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

  def slide(%{n: 11} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-11 slide--default">
      <div class="sl-eyebrow">An ordinary BEAM dependency</div>
      <h1>{Deck.title(@n)}</h1>
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

  def slide(%{n: 12} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-12 slide--default">
      <div class="sl-eyebrow">One rule representation · two uses</div>
      <h1>{Deck.title(@n)}</h1>
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

  def slide(%{n: 13} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-13 slide--default">
      <div class="sl-eyebrow">The gate has three answers</div>
      <h1>{Deck.title(@n)}</h1>
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

  def slide(%{n: 14} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-14 slide--default">
      <div class="sl-eyebrow">The real trust boundary</div>
      <h1>{Deck.title(@n)}</h1>
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

  def slide(%{n: 15} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-15 slide--default">
      <div class="sl-eyebrow">Scale the comparisons, keep the scope</div><h1>{Deck.title(@n)}</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <h2>Conservative edges</h2><p>
            same Thing<br />same action target<br />writer → trigger property
          </p>
        </div>
        <div class="sl-panel">
          <h2>Measured work</h2><p>rules<br />partitions<br />pairs considered / skipped</p>
        </div>
      </div>
      <blockquote>Grouping only by Thing can miss cross-Thing cascades.</blockquote>
    </section>
    """
  end

  def slide(%{n: 16} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-16 slide--demo">
      <div class="sl-eyebrow">Live demo · rule gate</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 01</p>
        <h1>{Deck.title(@n)}</h1>
        <p class="sl-live-caption">deploy rule A → check rule B → read the answer</p>
      </div>
    </section>
    """
  end

  def slide(%{n: 17} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-17 slide--demo">
      <div class="sl-eyebrow">Live demo · warehouse floor</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 02</p>
        <h1>{Deck.title(@n)}</h1>
        <p class="sl-live-caption">observe → enforce · read the measured counters</p>
      </div>
    </section>
    """
  end

  def slide(%{n: 18} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-18 slide--demo">
      <div class="sl-eyebrow">Live demo · diagnostics</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 03</p>
        <h1>{Deck.title(@n)}</h1>
        <p class="sl-live-caption">observations cite fields · inference stays separate</p>
      </div>
    </section>
    """
  end

  def slide(%{n: 19} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-19 slide--default">
      <div class="sl-eyebrow">The pattern transfers</div><h1>{Deck.title(@n)}</h1>
      <pre phx-no-curly-interpolation><code>invocations: [
    {:invoke_tool, "dose", %{}, "high_impact", :eu}
    ]</code></pre>
      <p class="sl-lede">Structured output in. Deterministic policy equations out.</p>
      <blockquote>This checks a policy, not the language model.</blockquote>
    </section>
    """
  end

  def slide(%{n: 20} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-20 slide--default">
      <div class="sl-eyebrow">The bundled AI policy model</div><h1>{Deck.title(@n)}</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <p>
            tool-call conflict<br />capability shadowing<br />pack/tool composition mismatch<br />sovereignty violation
          </p>
        </div>
        <div class="sl-panel">
          <p>authority escalation<br />approval-gate bypass<br />agent-loop cascade</p>
        </div>
      </div>
      <blockquote>If a property is not in the model, this detector did not check it.</blockquote>
    </section>
    """
  end

  def slide(%{n: 21} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-21 slide--default">
      <div class="sl-eyebrow">The same boundary works for generated policy</div>
      <h1>{Deck.title(@n)}</h1>
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

  def slide(%{n: 22} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-22 slide--demo">
      <div class="sl-eyebrow">Live demo · policy by hand</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 04</p>
        <h1>{Deck.title(@n)}</h1>
        <p class="sl-live-caption">three inputs · three readable answers</p>
      </div>
    </section>
    """
  end

  def slide(%{n: 23} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-23 slide--default">
      <div class="sl-eyebrow">Choose by property shape</div><h1>{Deck.title(@n)}</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <p>
            algebraic terms + transitions<br />temporal distributed behavior<br />bounded relations<br />constraints<br />protocol conformance
          </p>
        </div>
        <div class="sl-panel">
          <p>Maude<br />TLA+ / PlusCal<br />Alloy<br />SMT / Z3<br />types and model checking</p>
        </div>
      </div>
      <p class="sl-small sl-mt">Choose the model that makes the property clearest.</p>
    </section>
    """
  end

  def slide(%{n: 24} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-24 slide--default">
      <div class="sl-eyebrow">Before production</div><h1>{Deck.title(@n)}</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <h2>Engineering</h2><p>
            validate input<br />test translation<br />bound checking work<br />recover uncertain workers
          </p>
        </div>
        <div class="sl-panel">
          <h2>Evidence</h2><p>
            model + interpreter<br />validated input<br />typed verdict<br />activation decision
          </p>
        </div>
      </div>
      <p class="sl-small sl-mt">
        This simulation is not production evidence or a regulatory safety case.
      </p>
    </section>
    """
  end

  def slide(%{n: 25} = assigns) do
    ~H"""
    <section aria-label={Deck.title(@n)} class="slide slide-25 slide--closing">
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
