defmodule GoatmireWeb.RuleLive do
  @moduledoc """
  Rule authoring with the gate in the request.

  The check runs between the operator pressing the button and the rule
  existing, against the rules already deployed. The measured duration is shown
  on every result, including failures.
  """
  use GoatmireWeb, :live_view

  alias Goatmire.{Engine, Gate, Rules}

  @impl true
  def mount(_, _, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Goatmire.Talk.play_topic())
      Phoenix.PubSub.subscribe(Goatmire.PubSub, Engine.topic())
    end

    {:ok,
     socket
     |> assign(page_title: "New rule")
     |> assign(form: to_form(default_params()))
     |> assign(verdict: nil, submitted_rule: nil, deployed: false, running: false)
     |> assign_deployed_rules()
     |> restore_script()}
  end

  @impl true
  def handle_info({:talk_play, :rules, step}, socket)
      when step in [:seed_deployed, :load_example] do
    handle_event(Atom.to_string(step), %{}, socket)
  end

  def handle_info({:talk_play, :rules, :check}, socket) do
    handle_event("check", %{"rule" => socket.assigns.form.params}, socket)
  end

  def handle_info({:engine_deployed, _}, socket), do: {:noreply, assign_deployed_rules(socket)}

  def handle_info({:talk_state, :rules, state}, socket),
    do: {:noreply, apply_script(socket, state)}

  def handle_info({:talk_action_failed, :rules, _}, socket),
    do: {:noreply, put_flash(socket, :error, "The scripted check did not complete. Retry.")}

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate", %{"rule" => params}, socket) do
    {:noreply,
     assign(cancel_async(socket, :rule_operation),
       form: to_form(params),
       verdict: nil,
       submitted_rule: nil,
       deployed: false,
       running: false
     )}
  end

  def handle_event("check", %{"rule" => params}, socket) do
    case build_rule(params) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> assign(
           verdict: nil,
           submitted_rule: nil,
           deployed: false,
           running: true,
           form: to_form(params)
         )
         |> start_async(:rule_operation, fn ->
           {:ok, verdict, _} =
             Gate.verify_partitioned(Engine.deployed_rules() ++ [rule], scenario: :rule_form)

           {:checked, rule, verdict}
         end)}

      {:error, message} ->
        {:noreply,
         socket
         |> put_flash(:error, message)
         |> assign(form: to_form(params), verdict: nil, submitted_rule: nil, deployed: false)}
    end
  end

  def handle_event("deploy", _, socket) do
    if deployable?(socket) do
      deploy_current_candidate(socket)
    else
      {:noreply, put_flash(socket, :error, "Run a clean verification before deploying.")}
    end
  end

  def handle_event("load_example", _, socket) do
    [_, second] = Rules.research_state_conflict_pair()

    params = %{
      "id" => second.id,
      "thing_id" => second.thing_id,
      "trigger_op" => "prop_eq",
      "trigger_property" => "contact",
      "trigger_value" => "open",
      "action_property" => "switch",
      "action_value" => "off"
    }

    {:noreply,
     assign(cancel_async(socket, :rule_operation),
       form: to_form(params),
       verdict: nil,
       submitted_rule: nil,
       deployed: false,
       running: false
     )}
  end

  def handle_event("seed_deployed", _, socket) do
    [first, _] = Rules.research_state_conflict_pair()

    {:noreply,
     socket
     |> assign(running: true, verdict: nil, submitted_rule: nil, deployed: false)
     |> start_async(:rule_operation, fn ->
       {:seeded, Engine.deploy([first], scenario: :rule_form_seed)}
     end)}
  end

  @impl true
  def handle_async(:rule_operation, {:ok, {:checked, rule, verdict}}, socket) do
    {:noreply, assign(socket, running: false, verdict: verdict, submitted_rule: rule)}
  end

  def handle_async(:rule_operation, {:ok, {kind, {:ok, result}}}, socket) do
    socket = socket |> assign(running: false) |> assign_deployed_rules()

    if result.withheld == [] do
      message =
        if kind == :seeded,
          do: "Deployed the reproduced O3 switch-on rule. Now load O4.",
          else: "Deployed."

      {:noreply, socket |> assign(deployed: kind == :deployed) |> put_flash(:info, message)}
    else
      message =
        if kind == :seeded,
          do: "The gate withheld rule A. Restore verification and retry.",
          else: "Gate withheld: #{Enum.join(result.withheld, ", ")}"

      {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_async(:rule_operation, _, socket) do
    {:noreply,
     socket
     |> assign(running: false, verdict: nil, submitted_rule: nil)
     |> put_flash(:error, "Verification did not complete. Retry.")}
  end

  defp restore_script(socket), do: apply_script(socket, Goatmire.Talk.Actions.get(:rules))

  defp apply_script(socket, %{params: params} = state),
    do:
      socket
      |> assign(Map.delete(state, :params))
      |> assign(form: to_form(params), running: false)
      |> assign_deployed_rules()

  defp apply_script(socket, _), do: socket

  defp deployable?(socket) do
    match?(%{status: :clean}, socket.assigns.verdict) and
      is_map(socket.assigns.submitted_rule) and not socket.assigns.deployed and
      not socket.assigns.running
  end

  defp deploy_current_candidate(socket) do
    rule = socket.assigns.submitted_rule

    {:noreply,
     socket
     |> assign(running: true)
     |> start_async(:rule_operation, fn ->
       {:deployed, Engine.admit([rule], scenario: :rule_form)}
     end)}
  end

  # Fleet rules share templates ("agv-12-low-battery-route" is the same rule
  # as "agv-7-low-battery-route" bound to another Thing), so the deployed set
  # reads as a handful of counted templates instead of one chip per device.
  defp assign_deployed_rules(socket) do
    rules = Engine.deployed_rules()

    groups =
      rules
      |> Enum.frequencies_by(&String.replace_prefix(&1.id, "#{&1.thing_id}-", ""))
      |> Enum.sort_by(fn {label, count} -> {-count, label} end)

    assign(socket,
      deployed_rules: rules,
      deployed_count: length(rules),
      deployed_groups: groups
    )
  end

  defp default_params do
    [first, _] = Rules.research_state_conflict_pair()

    %{
      "id" => first.id,
      "thing_id" => first.thing_id,
      "trigger_op" => "prop_eq",
      "trigger_property" => "contact",
      "trigger_value" => "open",
      "action_property" => "switch",
      "action_value" => "on"
    }
  end

  defp build_rule(params) do
    with {:ok, id} <- required(params, "id", "rule id"),
         {:ok, thing_id} <- required(params, "thing_id", "thing id"),
         {:ok, trigger_property} <- required(params, "trigger_property", "trigger property"),
         {:ok, action_property} <- required(params, "action_property", "action property"),
         {:ok, action_value} <- required(params, "action_value", "action value"),
         {:ok, trigger} <-
           trigger(params["trigger_op"], trigger_property, params["trigger_value"]) do
      {:ok,
       %{
         id: id,
         thing_id: thing_id,
         trigger: trigger,
         actions: [{:set_prop, thing_id, action_property, action_value}],
         priority: 1
       }}
    end
  end

  defp required(params, key, label) do
    case Map.get(params, key, "") do
      value when not is_binary(value) ->
        {:error, "#{label} is required"}

      value ->
        required_string(String.trim(value), label)
    end
  end

  defp required_string(value, label) do
    case value do
      "" -> {:error, "#{label} is required"}
      value -> {:ok, value}
    end
  end

  defp trigger("always", _, _), do: {:ok, {:always}}

  defp trigger(op, property, value)
       when op in ~w(prop_lt prop_lte prop_eq prop_gte prop_gt) and is_binary(value) do
    if String.trim(value) == "" do
      {:error, "trigger value is required"}
    else
      {:ok, {trigger_operator(op), property, cast_value(value)}}
    end
  end

  defp trigger(_, _, _), do: {:error, "invalid trigger operator"}

  defp trigger_operator("prop_lt"), do: :prop_lt
  defp trigger_operator("prop_lte"), do: :prop_lte
  defp trigger_operator("prop_eq"), do: :prop_eq
  defp trigger_operator("prop_gte"), do: :prop_gte
  defp trigger_operator("prop_gt"), do: :prop_gt

  defp cast_value(value) do
    case Integer.parse(value) do
      {number, ""} ->
        number

      _ ->
        case Float.parse(value) do
          {number, ""} -> number
          _ -> value
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Create a rule</h1>
    <p class="lede">
      The conflict check runs between submit and existence — against the {length(@deployed_rules)} rule(s) already deployed, not against an empty set.
    </p>

    <p class="scope banner">
      Research-derived demo: these O3/O4-shaped rules reproduce SOTERIA's
      contact-open switch conflict. They are not copied applications or a
      historical incident.
    </p>

    <div id="rule-dashboard" class="grid cols-2">
      <div class="card">
        <.form for={@form} id="rule-form" phx-change="validate" phx-submit="check">
          <label for="rule-id">rule id</label>
          <input
            id="rule-id"
            type="text"
            name="rule[id]"
            value={@form[:id].value}
            placeholder="soteria-o4-contact-open-turn-off"
          />

          <label for="thing-id">thing id</label>
          <input id="thing-id" type="text" name="rule[thing_id]" value={@form[:thing_id].value} />

          <label>trigger</label>
          <div class="rule-fields">
            <select id="trigger-op" aria-label="Trigger operator" name="rule[trigger_op]">
              <option
                :for={op <- ~w(prop_lt prop_lte prop_eq prop_gte prop_gt always)}
                value={op}
                selected={@form[:trigger_op].value == op}
              >
                {op}
              </option>
            </select>
            <input
              id="trigger-property"
              aria-label="Trigger property"
              type="text"
              name="rule[trigger_property]"
              value={@form[:trigger_property].value}
            />
            <input
              id="trigger-value"
              aria-label="Trigger value"
              type="text"
              name="rule[trigger_value]"
              value={@form[:trigger_value].value}
            />
          </div>

          <label>action — set property</label>
          <div class="rule-fields">
            <input
              id="action-property"
              aria-label="Action property"
              type="text"
              name="rule[action_property]"
              value={@form[:action_property].value}
            />
            <input
              id="action-value"
              aria-label="Action value"
              type="text"
              name="rule[action_value]"
              value={@form[:action_value].value}
            />
          </div>

          <div class="rule-actions" style="margin-top:1rem">
            <button id="check-rule" type="submit" disabled={@running}>{if @running,
              do: "Checking…",
              else: "Check & create"}</button>
            <button
              id="deploy-rule-a"
              disabled={@running}
              type="button"
              class="ghost"
              phx-click="seed_deployed"
            >
              Deploy rule A
            </button>
            <button id="load-rule-b" type="button" class="ghost" phx-click="load_example">
              Load rule B
            </button>
          </div>
        </.form>
      </div>

      <div class="card">
        <h2 style="margin-top:0">Result</h2>

        <p :if={is_nil(@verdict)} class="note" style="color:var(--subtext)">
          Nothing submitted yet.
        </p>

        <.verdict_detail verdict={@verdict} />

        <div :if={@verdict && @verdict.status == :clean} class="row" style="margin-top:0.9rem">
          <button id="deploy-checked-rule" phx-click="deploy" disabled={@deployed or @running}>
            {if @deployed, do: "Deployed", else: "Deploy"}
          </button>
        </div>

        <div :if={@submitted_rule}>
          <h2>Term handed to Maude</h2>
          <pre>{inspect(@submitted_rule, pretty: true)}</pre>
        </div>
      </div>
    </div>

    <h2>
      Currently deployed
      <span :if={@deployed_count > 0} class="note">· {@deployed_count} rule(s)</span>
    </h2>
    <div class="card">
      <p :if={@deployed_groups == []} class="note" style="color:var(--subtext)">
        Nothing deployed.
      </p>
      <div :if={@deployed_groups != []} class="chip-list">
        <span :for={{label, count} <- @deployed_groups} class="chip">
          <code>{label}</code>
          <span :if={count > 1} class="chip-count">×{count}</span>
        </span>
      </div>
    </div>
    """
  end
end
