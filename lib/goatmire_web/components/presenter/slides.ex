defmodule GoatmireWeb.Presenter.Slides do
  @moduledoc """
  The 25 talk slides as function components.

  Ported from `docs/talk/slides/deck.md`; speaker notes stay archived there.
  Styled by `priv/static/assets/presenter-slides.css`.
  """

  use Phoenix.Component

  @titles [
    {1, "Zero Alert Storms"},
    {2, "Both apps were reasonable"},
    {3, "Both rules are reasonable"},
    {4, "The loop nobody designed"},
    {5, "The deployment question"},
    {6, "Sample behaviour—or decide an encoded predicate"},
    {7, "Four pieces"},
    {8, "Reduce is not search"},
    {9, "Four conflict categories"},
    {10, "A narrow claim can be strong"},
    {11, "Maude as an ordinary supervised dependency"},
    {12, "Verify the term the runtime executes"},
    {13, "Never turn “no answer” into “yes”"},
    {14, "Every arrow deserves a test"},
    {15, "Partition on interaction edges"},
    {16, "Catch the conflict before the rule exists"},
    {17, "Run the same shift change twice"},
    {18, "Ask the running system why"},
    {19, "An LLM may propose policy; it should not judge itself"},
    {20, "Exactly seven categories"},
    {21, "Put a deterministic gate around a probabilistic author"},
    {22, "Approval missing → clean revision → wrong jurisdiction"},
    {23, "Maude is not the only answer"},
    {24, "Keep the claim attached to its evidence"},
    {25, "Close"}
  ]

  @doc "Slide numbers and titles, in deck order, for the presenter chrome."
  @spec titles() :: [{pos_integer(), String.t()}]
  def titles, do: @titles

  attr :n, :integer, required: true

  @doc "Renders slide `n` of the deck."
  @spec slide(map()) :: Phoenix.LiveView.Rendered.t()
  # A dispatch table over the 25 slides; the branch count is the deck length,
  # not decision logic.
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
      19 -> slide_19(assigns)
      20 -> slide_20(assigns)
      21 -> slide_21(assigns)
      22 -> slide_22(assigns)
      23 -> slide_23(assigns)
      24 -> slide_24(assigns)
      25 -> slide_25(assigns)
    end
  end

  defp slide_1(assigns) do
    ~H"""
    <section class="slide slide-1 slide--title">
      <div class="sl-eyebrow">Goatmire 2026 · 30 minutes</div>
      <h1>Zero Alert Storms</h1>
      <p class="sl-lede">
        Formal verification for IoT automation—at the deployment gate, before
        reasonable rules become an unreasonable system.
      </p>
      <p class="sl-author">Tobias Bohwalli</p>
    </section>
    """
  end

  defp slide_2(assigns) do
    ~H"""
    <section class="slide slide-2 slide--default">
      <div class="sl-eyebrow">A published interaction</div>
      <h1>Both apps were reasonable</h1>
      <div class="sl-flow">
        <div class="sl-node">
          <div class="sl-label">smart-home app</div>
          <div class="sl-value">O3</div>
        </div>
        <span class="sl-arrow">+</span>
        <div class="sl-node">
          <div class="sl-label">smart-home app</div>
          <div class="sl-value">O4</div>
        </div>
        <span class="sl-arrow">→</span>
        <div class="sl-node">
          <div class="sl-label">installed together</div>
          <div class="sl-value">one home, one switch</div>
        </div>
      </div>
      <p class="sl-lede">
        From SOTERIA, a published smart-home safety analysis: two apps react to
        the same contact-open event — and set the same switch to conflicting values.
      </p>
      <p class="sl-small">Reproduced rule shape · controlled simulation · no real home involved.</p>
    </section>
    """
  end

  defp slide_3(assigns) do
    ~H"""
    <section class="slide slide-3 slide--default">
      <div class="sl-eyebrow">One event · one switch · two values</div>
      <h1>Both rules are reasonable</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <div class="sl-label">SOTERIA O3 shape</div>
          <h2>Contact opens</h2>
          <p>Set <code>switch</code> to <code>on</code>.</p>
        </div>
        <div class="sl-panel">
          <div class="sl-label">SOTERIA O4 shape</div>
          <h2>Contact opens</h2>
          <p>Set <code>switch</code> to <code>off</code>.</p>
        </div>
      </div>
    </section>
    """
  end

  defp slide_4(assigns) do
    ~H"""
    <section class="slide slide-4 slide--default">
      <div class="sl-eyebrow">Composition is the bug</div>
      <h1>The loop nobody designed</h1>
      <div class="sl-flow">
        <div class="sl-node">contact open</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">O3: on</div>
        <div class="sl-arrow">↔</div>
        <div class="sl-node">same switch</div>
        <div class="sl-arrow">↔</div>
        <div class="sl-node">O4: off</div>
      </div>
      <blockquote>Every component can work while the system is absurd.</blockquote>
    </section>
    """
  end

  defp slide_5(assigns) do
    ~H"""
    <section class="slide slide-5 slide--statement">
      <div class="sl-eyebrow">The deployment question</div>
      <div class="sl-statement">
        If the relationship exists before activation, why wait for telemetry to discover it?
      </div>
    </section>
    """
  end

  defp slide_6(assigns) do
    ~H"""
    <section class="slide slide-6 slide--default">
      <div class="sl-eyebrow">Testing and formal checking answer different questions</div>
      <h1>Sample behaviour—or decide an encoded predicate</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <div class="sl-label">tests / simulation</div>
          <div class="sl-value">Did these executions fail?</div>
          <p class="sl-small">
            Excellent for runtime code, timing, integration, and properties over generated cases.
          </p>
        </div>
        <div class="sl-panel">
          <div class="sl-label">equational detector</div>
          <div class="sl-value">Does this finite term match the conflict definition?</div>
          <p class="sl-small">Strong only inside the validated input and encoded model.</p>
        </div>
      </div>
    </section>
    """
  end

  defp slide_7(assigns) do
    ~H"""
    <section class="slide slide-7 slide--default">
      <div class="sl-eyebrow">A Maude mental model</div>
      <h1>Four pieces</h1>
      <div class="sl-four">
        <div class="sl-panel">
          <div class="sl-label">sorts</div>
          <div class="sl-value">types</div>
        </div>
        <div class="sl-panel">
          <div class="sl-label">operators</div>
          <div class="sl-value">constructors + functions</div>
        </div>
        <div class="sl-panel">
          <div class="sl-label">equations</div>
          <div class="sl-value">simplify</div>
        </div>
        <div class="sl-panel">
          <div class="sl-label">rewrite rules</div>
          <div class="sl-value">transition</div>
        </div>
      </div>
      <p class="sl-lede sl-mt">
        For an Elixir developer: complete function clauses versus possible state transitions.
      </p>
    </section>
    """
  end

  defp slide_8(assigns) do
    ~H"""
    <section class="slide slide-8 slide--default">
      <div class="sl-eyebrow">Two commands · two claims</div>
      <h1>Reduce is not search</h1>
      <pre><code>reduce in SWITCH : toggle(toggle(on)) .

    search [1] in CELL : idle =>* ready .</code></pre>
      <div class="sl-two sl-mt">
        <p>
          <strong>reduce</strong><br />
          <span class="sl-small">normal form under equations</span>
        </p>
        <p>
          <strong>search</strong><br />
          <span class="sl-small">reachable witness under transitions</span>
        </p>
      </div>
    </section>
    """
  end

  defp slide_9(assigns) do
    ~H"""
    <section class="slide slide-9 slide--default">
      <div class="sl-eyebrow">The bundled IoT model</div>
      <h1>Four conflict categories</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <h2>state conflict</h2>
          <p class="sl-small">same action target + property, incompatible writes</p>
        </div>
        <div class="sl-panel">
          <h2>environment conflict</h2>
          <p class="sl-small">actions push a shared environmental property apart</p>
        </div>
        <div class="sl-panel">
          <h2>state cascade</h2>
          <p class="sl-small">one action satisfies another rule's trigger</p>
        </div>
        <div class="sl-panel">
          <h2>state–environment cascade</h2>
          <p class="sl-small">the causal chain crosses state and environment</p>
        </div>
      </div>
    </section>
    """
  end

  defp slide_10(assigns) do
    ~H"""
    <section class="slide slide-10 slide--default">
      <div class="sl-eyebrow">Formal methods need a border</div>
      <h1>A narrow claim can be strong</h1>
      <div class="sl-two">
        <div class="sl-panel sl-panel--clean">
          <h2>Inside</h2>
          <p>validated finite rules<br />encoder<br />selected model<br />interpreter result</p>
        </div>
        <div class="sl-panel">
          <h2>Outside</h2>
          <p>physics · firmware timing · authorization · omitted hazards · deployment reality</p>
        </div>
      </div>
    </section>
    """
  end

  defp slide_11(assigns) do
    ~H"""
    <section class="slide slide-11 slide--default">
      <div class="sl-eyebrow">ExMaude</div>
      <h1>Maude as an ordinary supervised dependency</h1>
      <div class="sl-flow">
        <div class="sl-node">Elixir caller</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">named worker pool</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">Maude subprocess</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">typed result</div>
      </div>
      <pre><code>ExMaude.IoT.detect_conflicts(rules)</code></pre>
    </section>
    """
  end

  defp slide_12(assigns) do
    ~H"""
    <section class="slide slide-12 slide--default">
      <div class="sl-eyebrow">One representation · two consumers</div>
      <h1>Verify the term the runtime executes</h1>
      <div class="sl-branch-source" phx-no-curly-interpolation>%{trigger: …, actions: …}</div>
      <div class="sl-branch-arrow"><span>↙</span><span>↘</span></div>
      <div class="sl-two">
        <div class="sl-panel sl-panel--center">ExMaude encoder + detector</div>
        <div class="sl-panel sl-panel--center">rule evaluator + actuator</div>
      </div>
      <blockquote>
        A verified copy that drifts from runtime proves the wrong thing precisely.
      </blockquote>
    </section>
    """
  end

  defp slide_13(assigns) do
    ~H"""
    <section class="slide slide-13 slide--default">
      <div class="sl-eyebrow">The gate has three answers</div>
      <h1>Never turn “no answer” into “yes”</h1>
      <div class="sl-three">
        <div class="sl-verdict sl-verdict--clean">
          <strong>clean</strong>
          <span>detector ran; no modelled conflict found</span>
        </div>
        <div class="sl-verdict sl-verdict--conflicts">
          <strong>conflicts</strong>
          <span>concrete typed conflict + rule ids</span>
        </div>
        <div class="sl-verdict sl-verdict--unverified">
          <strong>unverified</strong>
          <span>timeout, unavailable backend, or rejected input</span>
        </div>
      </div>
    </section>
    """
  end

  defp slide_14(assigns) do
    ~H"""
    <section class="slide slide-14 slide--default">
      <div class="sl-eyebrow">The real trust boundary</div>
      <h1>Every arrow deserves a test</h1>
      <div class="sl-flow">
        <div class="sl-node">validated Elixir data</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">encoder</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">Maude term + module</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">parsed verdict</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">activation policy</div>
      </div>
    </section>
    """
  end

  defp slide_15(assigns) do
    ~H"""
    <section class="slide slide-15 slide--default">
      <div class="sl-eyebrow">Scale the comparison, not the claim</div>
      <h1>Partition on interaction edges</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <div class="sl-label">conservative edges</div>
          <div class="sl-value">same Thing</div>
          <div class="sl-value">same action target</div>
          <div class="sl-value">writer → trigger property</div>
        </div>
        <div class="sl-panel">
          <div class="sl-label">on screen</div>
          <div class="sl-value">rules</div>
          <div class="sl-value">partitions</div>
          <div class="sl-value">pairs skipped</div>
        </div>
      </div>
      <p class="sl-lede sl-mt">Grouping only by Thing would miss cross-Thing cascades.</p>
    </section>
    """
  end

  defp slide_16(assigns) do
    ~H"""
    <section class="slide slide-16 slide--demo">
      <div class="sl-eyebrow">Live demo · rule gate</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 01</p>
        <h1>Catch the conflict before the rule exists</h1>
        <p class="sl-live-caption">localhost:4000/rules</p>
      </div>
    </section>
    """
  end

  defp slide_17(assigns) do
    ~H"""
    <section class="slide slide-17 slide--demo">
      <div class="sl-eyebrow">Live demo · warehouse floor</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 02</p>
        <h1>Run the same shift change twice</h1>
        <p class="sl-live-caption">observe → enforce · read the measured counters</p>
      </div>
    </section>
    """
  end

  defp slide_18(assigns) do
    ~H"""
    <section class="slide slide-18 slide--demo">
      <div class="sl-eyebrow">Live demo · diagnostics</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 03</p>
        <h1>Ask the running system why</h1>
        <p class="sl-live-caption">BeamLens · bounded snapshot · cited fields · visible provider</p>
      </div>
    </section>
    """
  end

  defp slide_19(assigns) do
    ~H"""
    <section class="slide slide-19 slide--default">
      <div class="sl-eyebrow">The pattern transfers</div>
      <h1>An LLM may propose policy; it should not judge itself</h1>
      <pre phx-no-curly-interpolation><code>invocations: [
      {:invoke_tool, "dose", %{}, "high_impact", :eu}
    ]</code></pre>
      <p class="sl-lede sl-mt">Structured output in. Deterministic policy equations out.</p>
    </section>
    """
  end

  defp slide_20(assigns) do
    ~H"""
    <section class="slide slide-20 slide--default">
      <div class="sl-eyebrow">The bundled AI policy model</div>
      <h1>Exactly seven categories</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <p>
            tool-call conflict<br />capability shadowing<br />pack/tool mismatch<br />sovereignty
            violation
          </p>
        </div>
        <div class="sl-panel">
          <p>authority escalation<br />approval-gate bypass<br />agent-loop cascade</p>
        </div>
      </div>
      <blockquote>If it is not in this list, this detector did not check it.</blockquote>
    </section>
    """
  end

  defp slide_21(assigns) do
    ~H"""
    <section class="slide slide-21 slide--default">
      <div class="sl-eyebrow">Generate · verify · revise</div>
      <h1>Put a deterministic gate around a probabilistic author</h1>
      <div class="sl-flow">
        <div class="sl-node">generate structured rules</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">validate + encode</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">typed conflict</div>
        <div class="sl-arrow">→</div>
        <div class="sl-node">revise</div>
        <div class="sl-arrow">↺</div>
      </div>
    </section>
    """
  end

  defp slide_22(assigns) do
    ~H"""
    <section class="slide slide-22 slide--demo">
      <div class="sl-eyebrow">Live demo · policy by hand</div>
      <div class="sl-live">
        <p class="sl-live-label">LIVE · 04</p>
        <h1>Approval missing → clean revision → wrong jurisdiction</h1>
        <p class="sl-live-caption">Livebook · generated command, not a hand-copied command</p>
      </div>
    </section>
    """
  end

  defp slide_23(assigns) do
    ~H"""
    <section class="slide slide-23 slide--default">
      <div class="sl-eyebrow">Choose by property shape</div>
      <h1>Maude is not the only answer</h1>
      <table>
        <thead>
          <tr>
            <th>Need</th>
            <th>Reach for</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>algebraic terms + concurrent transitions</td>
            <td>Maude</td>
          </tr>
          <tr>
            <td>temporal distributed behaviours</td>
            <td>TLA+ / PlusCal</td>
          </tr>
          <tr>
            <td>bounded relational structures</td>
            <td>Alloy</td>
          </tr>
          <tr>
            <td>constraints and satisfiability</td>
            <td>SMT / Z3</td>
          </tr>
          <tr>
            <td>protocol/session conformance</td>
            <td>types, model checking, or both</td>
          </tr>
        </tbody>
      </table>
    </section>
    """
  end

  defp slide_24(assigns) do
    ~H"""
    <section class="slide slide-24 slide--default">
      <div class="sl-eyebrow">Before production</div>
      <h1>Keep the claim attached to its evidence</h1>
      <div class="sl-two">
        <div class="sl-panel">
          <h2>Engineering</h2>
          <p>
            validate input<br />test every translation edge<br />bound time + pool +
            search<br />restart uncertain workers
          </p>
        </div>
        <div class="sl-panel">
          <h2>Audit</h2>
          <p>
            model revision<br />interpreter version<br />validated term<br />typed
            result<br />activation decision
          </p>
        </div>
      </div>
    </section>
    """
  end

  defp slide_25(assigns) do
    ~H"""
    <section class="slide slide-25 slide--closing">
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
