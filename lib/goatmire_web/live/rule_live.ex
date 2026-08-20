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
    {:ok,
     socket
     |> assign(page_title: "New rule")
     |> assign(form: to_form(default_params()))
     |> assign(verdict: nil, submitted_rule: nil, deployed: false)
     |> assign_deployed_rules()}
  end

  @impl true
  def handle_event("validate", %{"rule" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params))}
  end

  def handle_event("check", %{"rule" => params}, socket) do
    case build_rule(params) do
      {:ok, rule} ->
        # A rule is only conflict-free relative to the set it is joining.
        candidate_set = socket.assigns.deployed_rules ++ [rule]
        {:ok, verdict} = Gate.verify(candidate_set, scenario: :rule_form)

        {:noreply,
         socket
         |> assign(verdict: verdict, submitted_rule: rule, deployed: false)
         |> assign(form: to_form(params))}

      {:error, message} ->
        {:noreply,
         socket
         |> put_flash(:error, message)
         |> assign(form: to_form(params))}
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

    {:noreply, assign(socket, form: to_form(params), verdict: nil, deployed: false)}
  end

  def handle_event("seed_deployed", _, socket) do
    [first, _] = Rules.research_state_conflict_pair()
    {:ok, _} = Engine.deploy([first], mode: :enforce, scenario: :rule_form_seed)

    {:noreply,
     socket
     |> assign_deployed_rules()
     |> put_flash(:info, "Deployed the reproduced O3 switch-on rule. Now load O4.")}
  end

  defp deployable?(socket) do
    match?(%{status: :clean}, socket.assigns.verdict) and
      is_map(socket.assigns.submitted_rule) and not socket.assigns.deployed
  end

  defp deploy_current_candidate(socket) do
    # Re-read the active set at the point of deployment. A second operator may
    # have deployed since this LiveView checked its candidate; the engine must
    # verify the current composition rather than overwrite it with stale state.
    rules = Engine.deployed_rules() ++ [socket.assigns.submitted_rule]

    case Engine.deploy(rules, mode: :enforce, scenario: :rule_form) do
      {:ok, %{withheld: []}} ->
        {:noreply,
         socket
         |> assign(deployed: true)
         |> assign_deployed_rules()
         |> put_flash(:info, "Deployed.")}

      {:ok, %{withheld: withheld}} ->
        {:noreply, put_flash(socket, :error, "Gate withheld: #{Enum.join(withheld, ", ")}")}
    end
  end

  defp assign_deployed_rules(socket) do
    rules = Engine.deployed_rules()
    assign(socket, deployed_rules: rules, deployed_ids: Enum.map(rules, & &1.id))
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
          <div class="row">
            <select
              id="trigger-op"
              aria-label="Trigger operator"
              name="rule[trigger_op]"
              style="width:auto"
            >
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
              style="width:auto;flex:1"
            />
            <input
              id="trigger-value"
              aria-label="Trigger value"
              type="text"
              name="rule[trigger_value]"
              value={@form[:trigger_value].value}
              style="width:6rem"
            />
          </div>

          <label>action — set property</label>
          <div class="row">
            <input
              id="action-property"
              aria-label="Action property"
              type="text"
              name="rule[action_property]"
              value={@form[:action_property].value}
              style="width:auto;flex:1"
            />
            <input
              id="action-value"
              aria-label="Action value"
              type="text"
              name="rule[action_value]"
              value={@form[:action_value].value}
              style="width:auto;flex:1"
            />
          </div>

          <div class="row" style="margin-top:1rem">
            <button id="check-rule" type="submit">Check &amp; create</button>
            <button id="deploy-rule-a" type="button" class="ghost" phx-click="seed_deployed">Deploy rule A</button>
            <button id="load-rule-b" type="button" class="ghost" phx-click="load_example">Load rule B</button>
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
          <button id="deploy-checked-rule" phx-click="deploy" disabled={@deployed}>
            {if @deployed, do: "Deployed", else: "Deploy"}
          </button>
        </div>

        <div :if={@submitted_rule}>
          <h2>Term handed to Maude</h2>
          <pre>{inspect(@submitted_rule, pretty: true)}</pre>
        </div>
      </div>
    </div>

    <h2>Currently deployed</h2>
    <div class="card">
      <p :if={@deployed_ids == []} class="note" style="color:var(--subtext)">Nothing deployed.</p>
      <ul :if={@deployed_ids != []}>
        <li :for={id <- @deployed_ids}>{id}</li>
      </ul>
    </div>
    """
  end
end
