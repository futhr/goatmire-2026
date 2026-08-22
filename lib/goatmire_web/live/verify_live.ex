defmodule GoatmireWeb.VerifyLive do
  @moduledoc """
  The verifier alone — three rule sets to reduce, each showing the term sent,
  the verdict, and the measured cost, plus the Scenario 5 agent-policy checks.

  Needs no fleet, no transport, and no network.
  """
  use GoatmireWeb, :live_view

  alias Goatmire.{Gate, Rules, ScenarioRunner, VerificationDemo}

  @impl true
  def mount(_, _, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Goatmire.Talk.play_topic())
    end

    {:ok,
     socket
     |> assign(page_title: "Verify")
     |> assign(results: %{}, running: nil, policy: nil, maude: maude_health())}
  end

  @impl true
  def handle_info({:talk_play, :verify, :run_policy}, socket) do
    handle_event("run_policy", %{}, socket)
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("run", %{"set" => set}, socket) do
    socket =
      socket
      |> assign(running: set)
      |> run_set(set)

    {:noreply, socket}
  end

  def handle_event("run_policy", _, socket) do
    {:noreply, assign(socket, policy: VerificationDemo.run())}
  end

  defp run_set(socket, "conflict") do
    rules = Rules.research_state_conflict_pair()
    {:ok, verdict} = Gate.verify(rules, scenario: :verify_page)
    put_result(socket, "conflict", verdict, rules)
  end

  defp run_set(socket, "clean") do
    {:ok, verdict} = Gate.verify(Rules.clean_set(), scenario: :verify_page)
    put_result(socket, "clean", verdict, Rules.clean_set())
  end

  defp run_set(socket, "cascade") do
    {:ok, %{verdict: verdict}} = ScenarioRunner.cascade_example()
    put_result(socket, "cascade", verdict, Rules.cascade_chain())
  end

  defp run_set(socket, _), do: assign(socket, running: nil)

  defp put_result(socket, key, verdict, rules) do
    socket
    |> assign(running: nil)
    |> assign(results: Map.put(socket.assigns.results, key, %{verdict: verdict, rules: rules}))
  end

  defp maude_health do
    case Gate.health() do
      {:ok, version} -> {:ok, version}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Verify</h1>
    <p class="lede">
      Equational reduction over <code>iot-rules.maude</code>
      and <code>ai-rules.maude</code>. No fleet, no transport,
      no network — just the interpreter.
    </p>

    <div class="card">
      <div class="row">
        <span :if={match?({:ok, _}, @maude)} class="badge clean">maude reachable</span>
        <span :if={match?({:error, _}, @maude)} class="badge unverified">maude unavailable</span>
        <span class="note">
          {case @maude do
            {:ok, version} -> version
            {:error, reason} -> inspect(reason)
          end}
        </span>
      </div>
      <p :if={match?({:error, _}, @maude)} class="scope">
        Every reduction below will return <code>unverified</code> until an
        interpreter is on <code>PATH</code> or <code>:maude_path</code>.
        That is the correct outcome, not a broken page.
      </p>
    </div>

    <div id="verify-dashboard" class="grid cols-2" style="margin-top:1rem">
      <div
        :for={
          {key, title, blurb} <- [
            {"conflict", "Two rules, one property",
             "The reproduced O3/O4 shape writes one switch to opposing states."},
            {"clean", "Five unrelated rules",
             "Different Things, no shared writes. The gate has to be able to say nothing is wrong."},
            {"cascade", "The five-rule loop",
             "Cool, vent, suspect, lock, disable. Nobody designed the cycle."}
          ]
        }
        class="card"
      >
        <h2 style="margin-top:0">{title}</h2>
        <p class="note" style="color:var(--subtext)">{blurb}</p>

        <.run_button
          id={"verify-#{key}"}
          phx-click="run"
          phx-value-set={key}
          disabled={@running == key}
          label={
            cond do
              @running == key -> "reducing…"
              @results[key] -> "reduce again"
              true -> "reduce"
            end
          }
        />

        <div :if={@results[key]} style="margin-top:0.9rem">
          <.verdict_detail verdict={@results[key].verdict} />
          <details style="margin-top:0.7rem">
            <summary class="note" style="cursor:pointer">term sent to Maude</summary>
            <div style="margin-top:0.5rem">
              <.term_block term={@results[key].rules} />
            </div>
          </details>
        </div>
      </div>

      <div class="card">
        <h2 style="margin-top:0">An agent policy</h2>
        <p class="note" style="color:var(--subtext)">
          Same machinery, different template: an agent that acts at high impact
          with no approval gate, the same policy once the gate is added, and an
          invocation outside the allowed jurisdiction.
        </p>

        <.run_button
          id="verify-policy"
          phx-click="run_policy"
          label={if @policy, do: "reduce again", else: "reduce"}
        />

        <div :if={@policy} style="margin-top:0.9rem">
          <.term_block term={@policy} />
          <p class="scope">
            A clean result means none of the seven conflict types this detector
            models were found. It is not a claim that the policy is safe.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
