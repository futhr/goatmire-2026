defmodule GoatmireWeb.CoreComponents do
  @moduledoc "Shared dashboard components."
  use Phoenix.Component

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :note, :string, default: nil
  attr :color, :string, default: nil

  @doc "One counter with its label and an optional footnote."
  @spec stat(map()) :: Phoenix.LiveView.Rendered.t()
  def stat(assigns) do
    ~H"""
    <div class="stat">
      <div class="label">{@label}</div>
      <div class="value" style={@color && "color: #{@color}"}>{@value}</div>
      <div :if={@note} class="note">{@note}</div>
    </div>
    """
  end

  attr :term, :any, required: true

  @doc "Pretty-printed Elixir term with Livebook editor-light syntax colours."
  # Makeup escapes the term text while emitting its own span markup, so the
  # raw render below cannot carry user-controlled HTML.
  # sobelow_skip ["XSS.Raw"]
  @spec term_block(map()) :: Phoenix.LiveView.Rendered.t()
  def term_block(assigns) do
    highlighted =
      assigns.term
      |> inspect(pretty: true)
      |> Makeup.highlight(lexer: Makeup.Lexers.ElixirLexer)

    assigns = assign(assigns, :highlighted, highlighted)

    ~H"""
    {Phoenix.HTML.raw(@highlighted)}
    """
  end

  attr :status, :atom, required: true

  @doc "Renders the verdict state."
  @spec verdict_badge(map()) :: Phoenix.LiveView.Rendered.t()
  def verdict_badge(assigns) do
    ~H"""
    <span class={"badge #{@status}"}>
      {case @status do
        :clean -> "no modeled conflict"
        :conflicts -> "conflict found"
        :unverified -> "unverified"
        _ -> "idle"
      end}
    </span>
    """
  end

  attr :verdict, :map, default: nil

  @doc "Conflict list, with the scope sentence that travels with every verdict."
  @spec verdict_detail(map()) :: Phoenix.LiveView.Rendered.t()
  def verdict_detail(assigns) do
    ~H"""
    <div :if={@verdict}>
      <div class="row">
        <.verdict_badge status={@verdict.status} />
        <span class="note">
          {@verdict.rule_count} rules · {@verdict.duration_us} µs measured
        </span>
      </div>

      <table :if={@verdict.conflicts != []} style="margin-top:0.8rem">
        <thead>
          <tr>
            <th>type</th>
            <th>rules</th>
            <th>reason</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={conflict <- @verdict.conflicts}>
            <td style="color: var(--red)">{conflict[:type]}</td>
            <td>
              {[conflict[:rule1], conflict[:rule2]] |> Enum.reject(&is_nil/1) |> Enum.join(" ↔ ")}
            </td>
            <td>{conflict[:reason]}</td>
          </tr>
        </tbody>
      </table>

      <p :if={@verdict.status == :unverified} class="scope">
        The detector did not run: {inspect(@verdict.reason)}. This is not a clean
        result. Nothing was deployed.
      </p>

      <p class="scope">{@verdict.scope}</p>
    </div>
    """
  end
end
