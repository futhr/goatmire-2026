defmodule Goatmire.Metrics do
  @moduledoc """
  Telemetry metrics, exported in Prometheus format on `:metrics_port`
  (9568 by default).

  Verification duration is a first-class metric alongside the alert counters: a
  gate whose cost is invisible is a gate that gets deleted the first week it is
  inconvenient.
  """

  use Supervisor

  import Telemetry.Metrics

  @doc "Starts the telemetry poller and Prometheus reporter supervisor."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    port = Application.get_env(:goatmire, :metrics_port, 9568)

    children = [
      {:telemetry_poller,
       measurements: [
         {__MODULE__, :dispatch_fleet_size, []}
       ],
       period: 10_000,
       name: Goatmire.Poller},
      # Register telemetry handlers before later children or callers emit. The
      # reporter defaults to asynchronous initialisation, which can otherwise
      # lose the first fleet/verification samples immediately after startup.
      {TelemetryMetricsPrometheus.Core,
       metrics: metrics(), name: reporter_name(), start_async: false},
      {Goatmire.Metrics.Exporter, port: port}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc "Registered name of the Prometheus core reporter."
  @spec reporter_name() :: atom()
  def reporter_name, do: :goatmire_prometheus

  @doc """
  Poller measurement: how many devices this node holds.

  A gauge rather than an event, because fleet size is a level and not
  something that happens — and because a simulator container's whole job is
  visible in this one number.
  """
  @spec dispatch_fleet_size() :: :ok
  def dispatch_fleet_size do
    :telemetry.execute([:goatmire, :fleet], %{devices: Goatmire.Fleet.count()}, %{})
  rescue
    # The registry may not be up yet during boot; a missing sample is better
    # than a crashing poller.
    _ -> :ok
  end

  @doc """
  The metric definitions.

  Exposed so a Livebook can render the same set with `Kino` instead of
  scraping, and so the definitions are testable without starting the exporter.
  """
  @spec metrics() :: [Telemetry.Metrics.t()]
  def metrics do
    [
      distribution("goatmire.verify.duration",
        event_name: [:goatmire, :verify, :stop],
        measurement: :duration_us,
        unit: :microsecond,
        tags: [:status, :scenario],
        tag_values: &verification_tag_values/1,
        description: "Wall-clock cost of one deployment-gate verification",
        reporter_options: [buckets: [100, 500, 1_000, 5_000, 25_000, 100_000, 500_000]]
      ),
      counter("goatmire.verify.total",
        event_name: [:goatmire, :verify, :stop],
        measurement: :rule_count,
        tags: [:status],
        description: "Verifications by outcome — clean, conflicts, or unverified"
      ),
      last_value("goatmire.verify.conflicts",
        event_name: [:goatmire, :verify, :stop],
        measurement: :conflict_count,
        tags: [:scenario],
        tag_values: &verification_tag_values/1,
        description: "Conflicts returned by the most recent verification"
      ),
      last_value("goatmire.verify.partitions",
        event_name: [:goatmire, :verify, :stop],
        measurement: :partitions,
        tags: [:scenario],
        tag_values: &verification_tag_values/1,
        description: "Independent interaction partitions in the most recent verification"
      ),
      last_value("goatmire.verify.pairs.considered",
        event_name: [:goatmire, :verify, :stop],
        measurement: :pairs_considered,
        tags: [:scenario],
        tag_values: &verification_tag_values/1,
        description: "Rule pairs considered inside interaction partitions"
      ),
      last_value("goatmire.verify.pairs.skipped",
        event_name: [:goatmire, :verify, :stop],
        measurement: :pairs_skipped,
        tags: [:scenario],
        tag_values: &verification_tag_values/1,
        description: "Cross-partition rule pairs omitted from the reduction"
      ),
      counter("goatmire.engine.events.total",
        event_name: [:goatmire, :engine, :event],
        measurement: :count,
        description: "Device readings ingested"
      ),
      counter("goatmire.engine.alerts.total",
        event_name: [:goatmire, :engine, :alert],
        measurement: :count,
        tags: [:property],
        description: "Operator-visible automation actions"
      ),
      counter("goatmire.engine.throttled.total",
        event_name: [:goatmire, :engine, :throttled],
        measurement: :count,
        description: "Commands dropped by the per-Thing actuation bound"
      ),
      last_value("goatmire.engine.deployed.rules",
        event_name: [:goatmire, :engine, :deploy],
        measurement: :deployed,
        tags: [:status, :mode],
        description: "Rules admitted by the most recent deployment"
      ),
      last_value("goatmire.engine.withheld.rules",
        event_name: [:goatmire, :engine, :deploy],
        measurement: :withheld,
        tags: [:status, :mode],
        description: "Rules the gate refused in the most recent deployment"
      ),
      last_value("goatmire.storm.alerts.total",
        event_name: [:goatmire, :storm, :tick],
        measurement: :alerts_total,
        tags: [:mode],
        description: "Cumulative alerts in the running storm, by deployment mode"
      ),
      distribution("ex_maude.iot.detect_conflicts.duration",
        event_name: [:ex_maude, :iot, :detect_conflicts, :stop],
        measurement: :duration,
        unit: {:native, :microsecond},
        tags: [:result],
        description: "Time inside ExMaude for an IoT conflict reduction",
        reporter_options: [buckets: [100, 500, 1_000, 5_000, 25_000, 100_000, 500_000]]
      ),
      distribution("ex_maude.ai.detect_conflicts.duration",
        event_name: [:ex_maude, :ai, :detect_conflicts, :stop],
        measurement: :duration,
        unit: {:native, :microsecond},
        tags: [:result],
        description: "Time inside ExMaude for an AI-policy reduction",
        reporter_options: [buckets: [100, 500, 1_000, 5_000, 25_000, 100_000, 500_000]]
      ),
      last_value("goatmire.fleet.devices",
        description: "Devices attached to this node"
      ),
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.system_counts.process_count")
    ]
  end

  # Scenario identifiers are useful as diagnostic metadata and may therefore
  # be tuples (for example `{:storm, :observe}`). Prometheus labels only accept
  # values implementing String.Chars, so normalise this one reporting boundary
  # without weakening the richer telemetry event consumed by BeamLens.
  defp verification_tag_values(%{scenario: scenario} = metadata) do
    %{metadata | scenario: scenario_label(scenario)}
  end

  defp scenario_label(nil), do: "unspecified"
  defp scenario_label(value) when is_atom(value), do: Atom.to_string(value)
  defp scenario_label(value) when is_binary(value), do: value
  defp scenario_label(value) when is_integer(value), do: Integer.to_string(value)
  defp scenario_label(value), do: inspect(value, limit: 8, printable_limit: 80)
end
