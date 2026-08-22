defmodule GoatmireWeb.MetricsLive do
  use GoatmireWeb, :live_view

  alias Goatmire.Diagnostics.Sampler

  @refresh_ms 1_000
  @windows [60, 300]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok,
     socket
     |> assign(page_title: "Metrics", window: 300, show_table: false)
     |> load()}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()
    {:noreply, load(socket)}
  end

  @impl true
  def handle_event("toggle_table", _, socket) do
    {:noreply, assign(socket, :show_table, !socket.assigns.show_table)}
  end

  def handle_event("window", %{"seconds" => seconds}, socket) do
    window = String.to_integer(seconds)
    window = if window in @windows, do: window, else: 300
    {:noreply, socket |> assign(window: window) |> load()}
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_ms)

  defp load(socket) do
    assign(socket, :sample, safe_series(socket.assigns.window))
  end

  defp safe_series(window) do
    Sampler.series(window)
  catch
    :exit, _ -> nil
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Metrics</h1>
    <p class="lede">
      The verifier and engine over the last {@window} s, from the same in-memory
      ring buffer the diagnostics chat cites. Sampled once per second; the window
      dies with the node, and that window is the story.
    </p>

    <div class="row" style="margin-bottom: 1.25rem">
      <button
        :for={seconds <- [60, 300]}
        type="button"
        class={if @window != seconds, do: "ghost"}
        phx-click="window"
        phx-value-seconds={seconds}
      >
        Last {seconds} s
      </button>
    </div>

    <p :if={is_nil(@sample)} class="scope banner">
      The sampler is not running — the demo branch may be restarting. This pane
      recovers on its own; nothing else is affected.
    </p>

    <div :if={@sample}>
      <div class="section-label">Engine</div>
      <section class="grid cols-4 metrics">
        <.metric label="Alerts / s" points={@sample.series.alerts} />
        <.metric label="Events / s" points={@sample.series.events} />
        <.metric label="Throttled / s" points={@sample.series.throttled} />
        <.metric label="Rules withheld" points={@sample.series.withheld} />
      </section>

      <div class="section-label">Verifier</div>
      <section class="grid cols-4 metrics">
        <.metric label="Maude pool in use" points={@sample.series.maude_in_use} />
        <.metric
          label="Checkout latency"
          points={@sample.series.maude_checkout_us}
          format={&format_us/1}
        />
        <.metric label="Fleet devices" points={@sample.series.fleet} />
        <.metric label="Scheduler %" points={@sample.series.scheduler_pct} />
      </section>

      <div class="section-label">Runtime</div>
      <section class="grid cols-4 metrics">
        <.metric label="Run queue" points={@sample.series.run_queue} />
        <.metric label="Processes" points={@sample.series.process_count} />
        <.metric label="Memory MB" points={@sample.series.memory_mb} />
        <.metric label="Samples" points={[]} value={"#{@sample.sample_count}"} />
      </section>

      <button type="button" class="ghost" phx-click="toggle_table" style="margin-top: 1.5rem">
        {if @show_table, do: "Hide summary table", else: "Window summary as a table"}
      </button>

      <div :if={@show_table}>
        <table style="margin-top: 0.75rem">
          <thead>
            <tr>
              <th>metric</th>
              <th>current</th>
              <th>min</th>
              <th>max</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{name, points} <- table_rows(@sample.series)}>
              <td>{name}</td>
              <td>{List.last(points) || 0}</td>
              <td>{Enum.min(points, fn -> 0 end)}</td>
              <td>{Enum.max(points, fn -> 0 end)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :points, :list, required: true
  attr :value, :string, default: nil
  attr :format, :any, default: nil

  defp metric(assigns) do
    current = assigns.value || format_value(List.last(assigns.points), assigns.format)
    assigns = assign(assigns, :current, current)

    ~H"""
    <div class="stat">
      <div class="label">{@label}</div>
      <div class="value">{@current}</div>
      <.sparkline :if={@points != []} points={@points} label={@label} />
    </div>
    """
  end

  defp format_value(nil, _), do: "0"
  defp format_value(value, nil), do: "#{value}"
  defp format_value(value, format), do: format.(value)

  defp format_us(us) when us >= 1_000, do: "#{Float.round(us / 1_000, 1)} ms"
  defp format_us(us), do: "#{us} µs"

  defp table_rows(series) do
    [
      {"alerts / s", series.alerts},
      {"events / s", series.events},
      {"throttled / s", series.throttled},
      {"rules withheld", series.withheld},
      {"maude pool in use", series.maude_in_use},
      {"checkout µs", series.maude_checkout_us},
      {"fleet devices", series.fleet},
      {"scheduler %", series.scheduler_pct},
      {"run queue", series.run_queue},
      {"processes", series.process_count},
      {"memory MB", series.memory_mb}
    ]
  end
end
