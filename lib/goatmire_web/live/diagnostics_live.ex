defmodule GoatmireWeb.DiagnosticsLive do
  @moduledoc """
  Prompt-driven diagnostics over the bounded BeamLens snapshot.

  Codex (ChatGPT plan) answers first; Ollama is the visible fallback — the
  provider badge changes on stage rather than switching silently.
  Deterministic evidence renders beside the model's prose because Maude, not
  the reasoner, owns the verdict.
  """

  use GoatmireWeb, :live_view

  alias Goatmire.Diagnostics.{Analysis, Provider, Snapshot}

  @analysis_timeout 30_000

  @impl true
  def mount(_, _, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Provider.topic())
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Goatmire.Talk.play_topic())
      Process.send_after(self(), :refresh_snapshot, 1_000)
    end

    {:ok,
     assign(socket,
       page_title: "Diagnostics",
       prompt:
         "Why did alerts rise in the last minute, what formal verdict accompanies this run, and what should I inspect next? Cite exact fields.",
       running: false,
       task: nil,
       messages: [],
       provider: Provider.status(),
       snapshot: Snapshot.read(:one_minute)
     )}
  end

  @impl true
  def handle_event("set_prompt", %{"prompt" => prompt}, socket) do
    if socket.assigns.running do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :prompt, prompt)}
    end
  end

  def handle_event("diagnose", %{"diagnostics" => %{"prompt" => prompt}}, socket) do
    prompt = String.trim(prompt)

    if prompt == "" or socket.assigns.running do
      {:noreply, socket}
    else
      task =
        Task.Supervisor.async_nolink(Goatmire.TaskSupervisor, fn ->
          Analysis.run(prompt, timeout: @analysis_timeout - 1_000)
        end)

      Process.send_after(self(), {:analysis_timeout, task.ref}, @analysis_timeout)

      messages = socket.assigns.messages ++ [%{role: :user, text: prompt}]

      {:noreply,
       assign(socket,
         running: true,
         task: task,
         prompt: prompt,
         messages: messages
       )}
    end
  end

  def handle_event("diagnose", _, socket) do
    {:noreply, put_flash(socket, :error, "Enter a diagnostic question and retry.")}
  end

  def handle_event("clear", _, %{assigns: %{running: true}} = socket), do: {:noreply, socket}

  def handle_event("clear", _, socket) do
    {:noreply, assign(socket, messages: [], prompt: "")}
  end

  @impl true
  def handle_info({:diagnostics_provider, status}, socket) do
    {:noreply, assign(socket, :provider, status)}
  end

  def handle_info({ref, result}, %{assigns: %{task: %{ref: ref}}} = socket) do
    Process.demonitor(ref, [:flush])
    {:noreply, complete(socket, result)}
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{assigns: %{task: %{ref: ref}}} = socket) do
    message = %{role: :error, text: Analysis.error_message(:beamlens_failed)}

    {:noreply,
     assign(socket, running: false, task: nil, messages: socket.assigns.messages ++ [message])}
  end

  def handle_info({:analysis_timeout, ref}, %{assigns: %{task: %{ref: ref} = task}} = socket) do
    Task.shutdown(task, :brutal_kill)
    message = %{role: :error, text: "BeamLens analysis exceeded the 30-second stage deadline."}

    {:noreply,
     assign(socket, running: false, task: nil, messages: socket.assigns.messages ++ [message])}
  end

  def handle_info({:analysis_timeout, _}, socket), do: {:noreply, socket}

  def handle_info(:refresh_snapshot, socket) do
    Process.send_after(self(), :refresh_snapshot, 1_000)
    {:noreply, assign(socket, :snapshot, Snapshot.read(:one_minute))}
  end

  def handle_info({:talk_play, :diagnostics, :diagnose}, socket) do
    handle_event("diagnose", %{"diagnostics" => %{"prompt" => socket.assigns.prompt}}, socket)
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp complete(socket, {:ok, result}) do
    # Markdown is converted once here rather than in render/1 — the snapshot
    # refresh re-renders every second and must not re-run MDEx per message.
    diagnosis =
      result
      |> format_diagnosis()
      |> Map.update!(:summaries, fn texts -> Enum.map(texts, &markdown/1) end)
      |> Map.update!(:hypotheses, fn texts -> Enum.map(texts, &markdown/1) end)

    message = %{role: :assistant, diagnosis: diagnosis}
    assign(socket, running: false, task: nil, messages: socket.assigns.messages ++ [message])
  end

  defp complete(socket, {:error, reason}) do
    message = %{
      role: :error,
      text: Analysis.error_message(reason)
    }

    assign(socket, running: false, task: nil, messages: socket.assigns.messages ++ [message])
  end

  defp complete(socket, _) do
    message = %{role: :error, text: Analysis.error_message(:beamlens_failed)}
    assign(socket, running: false, task: nil, messages: socket.assigns.messages ++ [message])
  end

  @doc false
  @spec format_diagnosis(map()) :: map()
  def format_diagnosis(%{stage_answer: answer}), do: answer

  def format_diagnosis(%{insights: [_ | _] = insights}) do
    %{
      summaries: Enum.map(insights, & &1.summary),
      observations:
        insights
        |> Enum.flat_map(& &1.matched_observations)
        |> Enum.uniq(),
      hypotheses:
        insights
        |> Enum.map(& &1.root_cause_hypothesis)
        |> Enum.reject(&is_nil/1),
      confidence:
        insights
        |> Enum.map(& &1.confidence)
        |> Enum.uniq(),
      grounded: Enum.all?(insights, & &1.hypothesis_grounded)
    }
  end

  def format_diagnosis(%{operator_results: [_ | _] = operator_results}) do
    notifications = Enum.flat_map(operator_results, &Map.get(&1, :notifications, []))

    if notifications == [] do
      format_snapshot_fallback(operator_results)
    else
      %{
        summaries:
          notifications
          |> Enum.map(& &1.context)
          |> Enum.uniq(),
        observations:
          notifications
          |> Enum.map(& &1.observation)
          |> Enum.uniq(),
        hypotheses:
          notifications
          |> Enum.map(& &1.hypothesis)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq(),
        confidence: [:medium],
        grounded: Enum.all?(notifications, &is_nil(&1.hypothesis))
      }
    end
  end

  def format_diagnosis(_) do
    %{
      summaries: ["BeamLens produced no correlated insight for this snapshot."],
      observations: ["Review the current measured fields below or ask a narrower question."],
      hypotheses: [],
      confidence: [:low],
      grounded: false
    }
  end

  defp format_snapshot_fallback(operator_results) do
    first_snapshot =
      operator_results
      |> Enum.flat_map(&Map.get(&1, :snapshots, []))
      |> List.first()

    current =
      case first_snapshot do
        %{data: %{current: current}} -> current
        _ -> %{}
      end

    verification = current[:verification]
    verdict = if verification, do: verification[:status], else: nil
    alert_rate = get_in(current, [:engine, :rates_per_second, :alerts]) || 0
    mode = current[:mode]

    verdict_summary =
      if verdict do
        "The recorded formal verdict is #{verdict}; the measured alert rate is #{alert_rate}/s."
      else
        "No verification has been recorded; the measured alert rate is #{alert_rate}/s."
      end

    %{
      summaries: [verdict_summary],
      observations: [
        "current.verification.status=#{verdict || "not_recorded"}",
        "current.engine.rates_per_second.alerts=#{alert_rate}",
        "current.mode=#{mode || "no_active_run"}"
      ],
      hypotheses: [],
      confidence: [:high],
      grounded: false
    }
  end

  defp provider_label(%{state: :available, provider: :codex, plan_type: plan_type}),
    do: "Codex ready · ChatGPT #{plan_type || "plan"} · not used yet"

  defp provider_label(%{provider: :codex, plan_type: plan_type}),
    do: "Codex · ChatGPT #{plan_type || "plan"}"

  defp provider_label(%{state: :available, provider: :ollama, reason: reason}),
    do: "Ollama ready · not used yet#{if reason, do: ": #{reason}", else: ""}"

  defp provider_label(%{provider: :ollama, reason: reason}),
    do: "Ollama · local fallback#{if reason, do: ": #{reason}", else: ""}"

  defp provider_label(%{state: :running}), do: "Codex · checking plan access"
  defp provider_label(%{state: :unavailable}), do: "diagnostics unavailable"
  defp provider_label(_), do: "reasoner not used yet"

  defp current(snapshot), do: snapshot.current || %{}

  # Templates and model prose carry Markdown (`code` citations, bold
  # verdicts). MDEx escapes embedded HTML by default, so the output contains
  # only markup MDEx itself generated — safe to render unescaped even for
  # model-authored text.
  # sobelow_skip ["XSS.Raw"]
  defp markdown(text) do
    case MDEx.to_html(text) do
      # credo:disable-for-next-line OeditusCredo.Check.Security.XSSVulnerability
      {:ok, html} -> Phoenix.HTML.raw(html)
      _ -> text
    end
  end

  @impl true
  def render(assigns) do
    current = current(assigns.snapshot)
    engine = current[:engine] || %{}
    rates = engine[:rates_per_second] || %{}
    verification = current[:verification] || %{}
    maude = current[:maude] || %{}
    pool = maude[:pool] || %{}
    beam = current[:beam] || %{}

    assigns =
      assign(assigns,
        rates: rates,
        verification: verification,
        pool: pool,
        beam: beam,
        provider_label: provider_label(assigns.provider)
      )

    ~H"""
    <h1>Ask the running system</h1>
    <p class="lede">
      Answers come from a bounded snapshot of application, Maude, fleet, and BEAM
      evidence — the reasoner explains, it never decides. Maude alone decides
      whether rules activate.
    </p>

    <div class="row" style="margin-bottom:1rem">
      <span id="diagnostic-provider" class="badge idle">{@provider_label}</span>
      <span class="badge idle">mode: {current(assigns.snapshot)[:mode] || "no run"}</span>
      <a href={~p"/beamlens"} class="note">open full BeamLens inspector →</a>
    </div>

    <div id="diagnostic-metrics" class="grid cols-4 metrics">
      <.stat label="alerts / second" value={to_string(@rates[:alerts] || 0)} />
      <.stat label="BEAM run queue" value={to_string(@beam[:run_queue] || 0)} />
      <.stat
        label="Maude pool"
        value={"#{@pool[:in_use] || 0}/#{@pool[:size] || 0}"}
        note="workers in use"
      />
      <.stat
        label="last verdict"
        value={to_string(@verification[:status] || "none")}
        note={if @verification[:duration_us], do: "#{@verification.duration_us} µs", else: "not run"}
      />
    </div>

    <div id="diagnostic-dashboard" class="grid dashboard-grid" style="margin-top:1.25rem">
      <div id="diagnosis-card" class="card">
        <h2 style="margin-top:0">Diagnosis</h2>

        <div :if={@messages == []} class="scope">
          Ask why the alert rate moved, whether the runtime or rule semantics are responsible,
          or what evidence changes between observe and enforce.
        </div>

        <div :for={message <- @messages} style="margin-bottom:1rem">
          <div :if={message.role == :user}>
            <div class="section-label">question</div>
            <p>{message.text}</p>
          </div>

          <div
            :if={message.role == :error}
            class="scope"
            style="color:var(--red)"
            role="alert"
            aria-live="assertive"
          >
            {message.text}
          </div>

          <div :if={message.role == :assistant}>
            <div class="section-label">observation</div>
            <div :for={summary <- message.diagnosis.summaries} class="answer-md">
              {summary}
            </div>
            <ul class="evidence">
              <li :for={observation <- message.diagnosis.observations}>{observation}</li>
            </ul>
            <div :if={message.diagnosis.hypotheses != []}>
              <div class="section-label">inference</div>
              <div :for={hypothesis <- message.diagnosis.hypotheses} class="answer-md">
                {hypothesis}
              </div>
            </div>
            <p class="scope">
              confidence: {Enum.join(message.diagnosis.confidence, ", ")} · hypothesis grounded: {message.diagnosis.grounded}
            </p>
          </div>
        </div>

        <form id="diagnostic-form" phx-submit="diagnose" aria-busy={to_string(@running)}>
          <label for="diagnostic-prompt">Question</label>
          <textarea
            id="diagnostic-prompt"
            name="diagnostics[prompt]"
            rows="4"
            style="width:100%"
            disabled={@running}
          >{@prompt}</textarea>
          <div class="row" style="margin-top:0.75rem">
            <button id="ask-beamlens" type="submit" disabled={@running}>
              {diagnose_label(@running, @provider)}
            </button>
            <button
              id="clear-diagnosis"
              type="button"
              class="ghost"
              phx-click="clear"
              disabled={@running}
            >
              clear
            </button>
          </div>
        </form>
      </div>

      <div id="diagnostic-evidence" class="card">
        <h2 style="margin-top:0">Stage prompts</h2>
        <button
          :for={
            prompt <- [
              "Why did alerts rise in the last minute, what formal verdict accompanies this run, and what should I inspect next? Cite exact fields.",
              "Is Maude pool saturation or rule semantics causing this run? Separate observation from inference.",
              "Compare the evidence in this enforcement run with the previous observe-only symptoms."
            ]
          }
          type="button"
          class="ghost stage-prompt"
          style="width:100%;margin-bottom:0.6rem;text-align:left"
          phx-click="set_prompt"
          phx-value-prompt={prompt}
          disabled={@running}
        >
          {prompt}
        </button>

        <h2>Deterministic evidence</h2>
        <pre id="deterministic-evidence">{Jason.encode!(%{
            status: @verification[:status],
            conflict_types: @verification[:conflict_types],
            stats: @verification[:stats],
            scope: @verification[:scope]
          }, pretty: true)}</pre>
      </div>
    </div>
    """
  end

  defp diagnose_label(true, _), do: "analysing…"
  defp diagnose_label(false, %{state: :unavailable}), do: "retry"
  defp diagnose_label(false, _), do: "Ask"
end
