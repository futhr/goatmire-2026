defmodule Goatmire.Config do
  @moduledoc """
  Runtime settings.

  No application account, API key, or tenant. Settings choose the transport,
  simulator size, and local model endpoints used by the demo.
  """

  @doc """
  What this node is for: `:engine`, `:simulator`, or `:notebook`.

  An engine node runs the verifier pool, the rule engine, and the dashboard. A
  simulator node runs devices only. A notebook node runs the verifier and rule
  engine without the web endpoint or diagnostics; the metrics exporter still
  starts unless `metrics_enabled` is false.
  """
  @spec role() :: :engine | :simulator | :notebook
  def role, do: get(:role)

  @doc "Transport adapter used by devices and the rule engine."
  @spec transport() :: module()
  def transport, do: get(:transport)
  @doc "Number of simulated fleet devices to start on this node."
  @spec fleet_size() :: non_neg_integer()
  def fleet_size, do: get(:fleet_size)
  @doc "Numeric offset applied to generated simulated-device identifiers."
  @spec fleet_offset() :: non_neg_integer()
  def fleet_offset, do: get(:fleet_offset)
  @doc "Whether the configured simulated fleet starts with the application."
  @spec autostart_fleet?() :: boolean()
  def autostart_fleet?, do: get(:autostart_fleet)
  @doc "Simulation interval in milliseconds; zero disables periodic ticks."
  @spec device_tick_ms() :: non_neg_integer()
  def device_tick_ms, do: get(:device_tick_ms)
  @doc "Physical devices declared for liveness monitoring."
  @spec real_devices() :: [keyword()]
  def real_devices, do: get(:real_devices)
  @doc "Modbus sensors declared for polling."
  @spec modbus_sensors() :: [keyword()]
  def modbus_sensors, do: get(:modbus_sensors)

  @doc """
  Whether to run the VDA 5050 bridge and have simulated AGVs speak the
  standard. Off by default so a brokerless laptop run stays quiet.
  """
  @spec vda5050_enabled?() :: boolean()
  def vda5050_enabled?, do: get(:vda5050_enabled)

  @doc "Base URL of the OpenAI-compatible rule-generation endpoint."
  @spec llm_base_url() :: String.t()
  def llm_base_url, do: get(:llm_base_url)
  @doc "Rule-generation request deadline in milliseconds."
  @spec llm_timeout_ms() :: pos_integer()
  def llm_timeout_ms, do: get(:llm_timeout_ms)

  @doc "Loopback completion bridge used by BeamLens."
  @spec diagnostics_bridge_url() :: String.t()
  def diagnostics_bridge_url, do: get(:diagnostics_bridge_url)

  @doc "Optional Codex model override; nil accepts the account default."
  @spec diagnostics_codex_model() :: String.t() | nil
  def diagnostics_codex_model, do: get(:diagnostics_codex_model)
  @doc "Codex app-server deadline in milliseconds."
  @spec diagnostics_codex_timeout_ms() :: pos_integer()
  def diagnostics_codex_timeout_ms, do: get(:diagnostics_codex_timeout_ms)

  @doc "Base URL of the local Ollama OpenAI-compatible API."
  @spec diagnostics_ollama_base_url() :: String.t()
  def diagnostics_ollama_base_url, do: get(:diagnostics_ollama_base_url)

  @doc "Pinned Ollama model used when Codex plan access is unavailable."
  @spec diagnostics_ollama_model() :: String.t()
  def diagnostics_ollama_model, do: get(:diagnostics_ollama_model)
  @doc "Ollama diagnostic request deadline in milliseconds."
  @spec diagnostics_ollama_timeout_ms() :: pos_integer()
  def diagnostics_ollama_timeout_ms, do: get(:diagnostics_ollama_timeout_ms)

  @doc "Maximum output tokens permitted for one local diagnostic explanation."
  @spec diagnostics_ollama_max_tokens() :: pos_integer()
  def diagnostics_ollama_max_tokens, do: get(:diagnostics_ollama_max_tokens)

  @doc "Whether to start the Prometheus exporter."
  @spec metrics_enabled?() :: boolean()
  def metrics_enabled?, do: get(:metrics_enabled)

  @doc "BAML client registry pointing only at Goatmire's loopback provider bridge."
  @spec diagnostics_client_registry() :: map()
  def diagnostics_client_registry do
    %{
      primary: "GoatmireDiagnostics",
      clients: [
        %{
          name: "GoatmireDiagnostics",
          provider: "openai-generic",
          options: %{
            base_url: diagnostics_bridge_url(),
            model: "goatmire-diagnostics"
          }
        }
      ]
    }
  end

  @doc """
  Configured model tag for rule generation.

  The bang is historical; every getter in this module raises on a missing
  key, so this one is no stricter than its neighbours.
  """
  @spec llm_model!() :: String.t()
  def llm_model!, do: get(:llm_model)

  defp get(key), do: Application.fetch_env!(:goatmire, key)
end
