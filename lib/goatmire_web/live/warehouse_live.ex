defmodule GoatmireWeb.WarehouseLive do
  @moduledoc """
  The floor, live.

  Every dot is a simulated or transport-observed device. Storm counters are
  read from the engine, not the scenario.
  """
  use GoatmireWeb, :live_view

  alias Goatmire.{Engine, Fleet, Warehouse}
  alias Goatmire.Scenario.Storm

  @refresh_ms 1_000
  @device_render_limit 500
  @max_fleet_size 6_000
  @max_duration_seconds 300

  @impl true
  def mount(_, _, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Storm.topic())
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Goatmire.Talk.play_topic())
      :timer.send_interval(@refresh_ms, self(), :refresh)
    end

    {:ok,
     socket
     |> assign(page_title: "Warehouse")
     |> assign(devices: [], device_count: 0, alerts: [], storm: nil, frame: nil, running: false)
     |> assign(fleet_size: 60, duration: 30)
     |> refresh()}
  end

  @impl true
  def handle_event("start_fleet", _, socket) do
    Fleet.stop_all()
    {:ok, _} = Fleet.start_simulated_fleet(socket.assigns.fleet_size, tick_ms: 500)
    {:noreply, refresh(socket)}
  end

  def handle_event("stop_fleet", _, %{assigns: %{running: true}} = socket), do: {:noreply, socket}

  def handle_event("stop_fleet", _, socket) do
    Fleet.stop_all()
    {:noreply, refresh(socket)}
  end

  def handle_event("storm", _, %{assigns: %{running: true}} = socket), do: {:noreply, socket}

  def handle_event("storm", %{"mode" => mode}, socket) when mode in ~w(observe enforce) do
    mode = String.to_existing_atom(mode)

    opts = [
      mode: mode,
      fleet_size: socket.assigns.fleet_size,
      duration_seconds: socket.assigns.duration,
      tick_ms: 250,
      keep_fleet: true
    ]

    # Runs beside the LiveView so the dashboard keeps rendering its frames.
    view = self()
    Task.Supervisor.start_child(Goatmire.TaskSupervisor, fn -> run_storm(view, opts) end)

    {:noreply, assign(socket, running: true, frame: nil, storm: nil, alerts: [])}
  end

  def handle_event("storm", _, socket) do
    {:noreply, put_flash(socket, :error, "Unknown storm mode. Choose observe or enforce.")}
  end

  def handle_event("set_fleet_size", %{"value" => value}, socket) do
    fleet_size = bounded_int(value, socket.assigns.fleet_size, 1, @max_fleet_size)
    {:noreply, assign(socket, fleet_size: fleet_size)}
  end

  def handle_event("set_duration", %{"value" => value}, socket) do
    duration = bounded_int(value, socket.assigns.duration, 1, @max_duration_seconds)
    {:noreply, assign(socket, duration: duration)}
  end

  def handle_event("configure_storm", params, socket) do
    fleet_size =
      bounded_int(params["fleet_size"], socket.assigns.fleet_size, 1, @max_fleet_size)

    duration =
      bounded_int(params["duration"], socket.assigns.duration, 1, @max_duration_seconds)

    {:noreply, assign(socket, fleet_size: fleet_size, duration: duration)}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, refresh(socket)}

  def handle_info({:storm_tick, frame}, socket), do: {:noreply, assign(socket, frame: frame)}

  def handle_info({:storm_finished, summary}, socket) do
    {:noreply, assign(socket, storm: summary, running: false)}
  end

  def handle_info({:storm_started, _}, socket), do: {:noreply, assign(socket, running: true)}

  def handle_info({:storm_failed, message}, socket) do
    {:noreply,
     socket
     |> assign(running: false, frame: nil)
     |> put_flash(:error, message)}
  end

  def handle_info({:talk_play, :warehouse, mode}, socket) when mode in [:observe, :enforce] do
    handle_event("storm", %{"mode" => Atom.to_string(mode)}, socket)
  end

  def handle_info({:talk_play, :warehouse, :clear}, socket) do
    handle_event("stop_fleet", %{}, socket)
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp run_storm(view, opts) do
    {:ok, _} = Storm.run(opts)
    :ok
  rescue
    _ -> send(view, {:storm_failed, "Storm could not complete. Reset and retry."})
  catch
    :exit, _ -> send(view, {:storm_failed, "Storm could not complete. Reset and retry."})
  end

  defp refresh(socket) do
    engine = Engine.status()
    local_count = Fleet.count()

    devices =
      (Fleet.snapshot_sample(@device_render_limit, 500) ++
         Enum.map(engine.observed_things, &observed_device/1))
      |> Enum.uniq_by(& &1.thing_id)
      |> Enum.take(@device_render_limit)

    assign(socket,
      devices: devices,
      device_count: max(local_count, engine.things_seen),
      status_counts: status_counts(devices),
      alerts: engine.recent_alerts,
      engine: engine
    )
  end

  defp observed_device(%{thing_id: thing_id, properties: properties}) do
    %{
      thing_id: thing_id,
      kind: :observed,
      status: :observed,
      battery: properties["battery"],
      position: observed_position(properties["position"]),
      zone: properties["zone"],
      destination: properties["destination"],
      mode: observed_mode(properties["mode"])
    }
  end

  defp observed_position(%{"x" => x, "y" => y}), do: %{x: x, y: y}
  defp observed_position(%{x: x, y: y}), do: %{x: x, y: y}
  defp observed_position(_), do: nil

  defp observed_mode("charging"), do: :charging
  defp observed_mode("driving"), do: :driving
  defp observed_mode("idle"), do: :idle
  defp observed_mode(mode), do: mode

  defp bounded_int(value, fallback, minimum, maximum) do
    string = to_string(value)
    normalized = String.trim(string)

    case Integer.parse(normalized) do
      {number, ""} -> min(max(number, minimum), maximum)
      _ -> fallback
    end
  end

  # One classification feeds the dot colours and the legend counts, so the
  # legend can never disagree with the floor. The fills are Livebook palette
  # steps chosen to stay separable under red-green colour blindness; stale is
  # a hollow ring so liveness problems never rely on colour alone.
  defp device_state(%{status: status}) when status in [:stale, :never_seen, :unreachable],
    do: :stale

  defp device_state(%{battery: battery}) when is_number(battery) and battery < 20,
    do: :low_battery

  defp device_state(%{mode: :charging}), do: :charging
  defp device_state(%{mode: :driving}), do: :driving
  defp device_state(_), do: :idle

  defp dot_fill(:stale), do: "var(--surface)"
  defp dot_fill(:low_battery), do: "var(--status-low)"
  defp dot_fill(:charging), do: "var(--status-charging)"
  defp dot_fill(:driving), do: "var(--status-driving)"
  defp dot_fill(:idle), do: "var(--status-idle)"

  defp dot_stroke(%{kind: :real}, _), do: "var(--heading)"
  defp dot_stroke(_, :stale), do: "var(--status-stale)"
  defp dot_stroke(_, :charging), do: "var(--status-charging-edge)"
  defp dot_stroke(_, _), do: "none"

  defp status_counts(devices) do
    counts = Enum.frequencies_by(devices, &device_state/1)
    Map.merge(%{driving: 0, charging: 0, low_battery: 0, idle: 0, stale: 0}, counts)
  end

  defp position(%{position: %{x: x, y: y}}), do: {x, y}
  defp position(device), do: Warehouse.home_position(device.thing_id)

  @impl true
  def render(assigns) do
    {width, height} = Warehouse.dimensions()

    assigns =
      assign(assigns,
        hall_width: width,
        hall_height: height,
        max_fleet_size: @max_fleet_size,
        max_duration_seconds: @max_duration_seconds
      )

    ~H"""
    <h1>Warehouse floor</h1>
    <p class="lede">
      {@device_count} Thing(s) tracked · {@engine.deployed_count} rule(s) deployed · {length(
        @engine.withheld
      )} withheld by the gate
    </p>

    <div id="warehouse-metrics" class="grid cols-4 metrics">
      <.stat label="events ingested" value={to_string(@engine.counters.events)} />
      <.stat
        label="alerts"
        value={to_string(@engine.counters.alerts)}
        color={if @engine.counters.alerts > 500, do: "var(--red)", else: "var(--green)"}
        note="operator-visible actuations"
      />
      <.stat
        label="throttled"
        value={to_string(@engine.counters.throttled)}
        note="dropped by the per-Thing bound"
      />
      <.stat label="things seen" value={to_string(@engine.things_seen)} />
    </div>

    <div id="warehouse-dashboard" class="grid dashboard-grid" style="margin-top:1.25rem">
      <div id="floor-card" class="card">
        <h2 style="margin-top:0">Floor</h2>
        <svg
          viewBox={"0 0 #{@hall_width} #{@hall_height}"}
          style="width:100%;height:auto;background:var(--surface);border:1px solid var(--overlay);border-radius:0.5rem"
          preserveAspectRatio="xMidYMid meet"
          role="img"
          aria-label="Live floor plan with one dot per device, coloured by status"
        >
          <line
            :for={n <- 1..2}
            x1={@hall_width / 3 * n}
            y1="0"
            x2={@hall_width / 3 * n}
            y2={@hall_height}
            stroke="var(--surface-muted)"
            stroke-width="0.15"
          />
          <line
            :for={n <- 1..2}
            x1="0"
            y1={@hall_height / 3 * n}
            x2={@hall_width}
            y2={@hall_height / 3 * n}
            stroke="var(--surface-muted)"
            stroke-width="0.15"
          />
          <rect
            x="0"
            y="0"
            width={@hall_width / 3}
            height={@hall_height / 3}
            fill="#fdf3f4"
            stroke="#f1a3a6"
            stroke-width="0.15"
            stroke-dasharray="0.8 0.5"
          />
          <rect
            :for={{_id, {dx, dy}} <- Warehouse.docks()}
            x={dx - 0.6}
            y={@hall_height - dy - 0.6}
            width="1.2"
            height="1.2"
            rx="0.2"
            fill="var(--overlay-strong)"
          />

          <circle
            :for={device <- @devices}
            cx={elem(position(device), 0)}
            cy={@hall_height - elem(position(device), 1)}
            r={if device.kind == :real, do: 1.1, else: 0.7}
            fill={dot_fill(device_state(device))}
            stroke={dot_stroke(device, device_state(device))}
            stroke-width={if device.kind == :real, do: "0.2", else: "0.25"}
          >
            <title>{device.thing_id} · {device.status} · battery {device.battery}</title>
          </circle>

          <text
            x="1"
            y="2.4"
            fill="var(--subtext)"
            font-size="1.5"
            font-weight="500"
            stroke="var(--surface)"
            stroke-width="0.35"
            paint-order="stroke"
          >
            zone-7 · closed
          </text>
        </svg>
        <div class="legend" aria-label="Device status legend">
          <span class="entry">
            <span class="dot" style="background:var(--status-driving)"></span>
            driving · {@status_counts.driving}
          </span>
          <span class="entry">
            <span class="dot" style="background:var(--status-charging)"></span>
            charging · {@status_counts.charging}
          </span>
          <span class="entry">
            <span class="dot" style="background:var(--status-low)"></span>
            battery low · {@status_counts.low_battery}
          </span>
          <span class="entry">
            <span class="dot" style="background:var(--status-idle)"></span>
            idle · {@status_counts.idle}
          </span>
          <span class="entry">
            <span class="dot hollow"></span> stale · {@status_counts.stale}
          </span>
          <span class="entry">
            <span class="dot" style="background:var(--overlay-strong);border-radius:2px"></span> dock
          </span>
        </div>
        <p :if={@device_count <= length(@devices)} class="scope">
          Dots are simulated locally or observed over the transport. The
          stage demo does not depend on physical hardware.
        </p>
        <p :if={@device_count > length(@devices)} class="scope">
          Showing {length(@devices)} of {@device_count} devices. The visual sample is bounded;
          engine counters and rule evaluation still cover the complete fleet.
        </p>
      </div>

      <div id="shift-card" class="card">
        <h2 style="margin-top:0">Shift change</h2>
        <form id="storm-configuration" phx-change="configure_storm">
          <div class="storm-config">
            <label for="fleet-size" style="margin:0">fleet</label>
            <input
              id="fleet-size"
              name="fleet_size"
              aria-label="Fleet size"
              type="number"
              min="1"
              max={@max_fleet_size}
              value={@fleet_size}
              data-server-value={@fleet_size}
              disabled={@running}
            />
            <label for="storm-duration" style="margin:0">seconds</label>
            <input
              id="storm-duration"
              name="duration"
              aria-label="Storm duration in seconds"
              type="number"
              min="1"
              max={@max_duration_seconds}
              value={@duration}
              data-server-value={@duration}
              disabled={@running}
            />
          </div>
        </form>
        <div class="storm-actions" style="margin-top:0.8rem">
          <button
            id="run-observe"
            phx-click="storm"
            phx-value-mode="observe"
            disabled={@running}
            title="Run the shift change; conflicting rules stay deployed"
          >
            Observe
          </button>
          <button
            id="run-enforce"
            phx-click="storm"
            phx-value-mode="enforce"
            disabled={@running}
            class="ghost"
            title="Run the same shift change with conflicting rules withheld"
          >
            Enforce
          </button>
          <button
            id="clear-fleet"
            phx-click="stop_fleet"
            class="ghost"
            disabled={@running}
            title="Stop every simulated device"
          >
            Clear
          </button>
        </div>

        <div :if={@frame} style="margin-top:1rem">
          <div class="row">
            <span class="badge idle">{@frame.mode}</span>
            <span class="note">second {@frame.second} / {@frame.duration}</span>
          </div>
          <div class="stat" style="margin-top:0.5rem">
            <div class="label">alerts so far</div>
            <div
              class="value"
              style={"color: #{if @frame.mode == :enforce, do: "var(--green)", else: "var(--red)"}"}
            >
              {@frame.alerts_total}
            </div>
            <div class="note">{@frame.alerts_this_second} this second</div>
          </div>
        </div>

        <div :if={@storm} style="margin-top:1rem">
          <h2>Measured</h2>
          <table>
            <tbody>
              <tr>
                <td>mode</td><td>{@storm.mode}</td>
              </tr>
              <tr>
                <td>rules deployed</td><td>{@storm.rules_deployed}</td>
              </tr>
              <tr>
                <td>rules withheld</td><td>{length(@storm.rules_withheld)}</td>
              </tr>
              <tr>
                <td>events</td><td>{@storm.events}</td>
              </tr>
              <tr>
                <td>alerts</td><td>{@storm.alerts}</td>
              </tr>
              <tr>
                <td>throttled</td><td>{@storm.throttled}</td>
              </tr>
            </tbody>
          </table>
          <p class="scope">
            Measured output of this simulator on this machine, at this fleet size
            and tick rate. Not a benchmark and not an incident report.
          </p>
        </div>
      </div>
    </div>

    <h2>Alert feed</h2>
    <div id="alert-feed" class="card">
      <p :if={@alerts == []} class="note" style="color:var(--subtext)">Quiet.</p>
      <div :if={@alerts != []} class="feed">
        <table>
          <thead>
            <tr>
              <th>thing</th>
              <th>property</th>
              <th>value</th>
              <th>#</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={alert <- @alerts}>
              <td>{alert.thing_id}</td>
              <td>{alert.property}</td>
              <td>{inspect(alert.value)}</td>
              <td>{alert.total}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
