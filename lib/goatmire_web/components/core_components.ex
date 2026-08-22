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

  attr :points, :list, required: true
  attr :label, :string, required: true
  attr :width, :integer, default: 120
  attr :height, :integer, default: 32

  @doc "Server-rendered sparkline: 2px line, soft area wash, ringed current-point dot."
  @spec sparkline(map()) :: Phoenix.LiveView.Rendered.t()
  def sparkline(assigns) do
    assigns =
      assigns
      |> assign(:geometry, sparkline_geometry(assigns.points, assigns.width, assigns.height))
      |> assign(:summary, sparkline_summary(assigns.points))

    ~H"""
    <svg
      :if={@geometry}
      class="sparkline"
      width={@width}
      height={@height}
      viewBox={"0 0 #{@width} #{@height}"}
      role="img"
      aria-label={"#{@label}: #{@summary}"}
    >
      <title>{@label}: {@summary}</title>
      <polygon points={@geometry.area} fill="var(--blue-soft)" />
      <polyline
        points={@geometry.line}
        fill="none"
        stroke="var(--blue)"
        stroke-width="2"
        stroke-linejoin="round"
        stroke-linecap="round"
      />
      <circle
        cx={@geometry.cx}
        cy={@geometry.cy}
        r="3.5"
        fill="var(--blue)"
        stroke="var(--surface)"
        stroke-width="2"
      />
    </svg>
    """
  end

  defp sparkline_geometry([], _, _), do: nil

  defp sparkline_geometry(points, width, height) do
    points = downsample(points, width)
    count = length(points)
    {min, max} = Enum.min_max(points)
    span = max - min
    x_left = 2
    x_right = width - 6
    y_top = 5
    y_bottom = height - 6

    coords =
      points
      |> Enum.with_index()
      |> Enum.map(fn {value, index} ->
        x = if count == 1, do: x_right, else: x_left + (x_right - x_left) * index / (count - 1)

        y =
          if span == 0,
            do: (y_top + y_bottom) / 2,
            else: y_bottom - (y_bottom - y_top) * (value - min) / span

        {Float.round(x * 1.0, 1), Float.round(y * 1.0, 1)}
      end)

    line = Enum.map_join(coords, " ", fn {x, y} -> "#{x},#{y}" end)
    {first_x, _} = List.first(coords)
    {last_x, last_y} = List.last(coords)
    area = "#{first_x},#{y_bottom} #{line} #{last_x},#{y_bottom}"

    %{line: line, area: area, cx: last_x, cy: last_y}
  end

  # Bucket by max so one-second spikes stay visible at one point per pixel.
  defp downsample(points, width) do
    count = length(points)

    if count <= width do
      points
    else
      points
      |> Enum.chunk_every(ceil(count / width))
      |> Enum.map(&Enum.max/1)
    end
  end

  defp sparkline_summary([]), do: "no samples"

  defp sparkline_summary(points) do
    {min, max} = Enum.min_max(points)
    "now #{List.last(points)}, min #{min}, max #{max}"
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

  attr :label, :string, required: true
  attr :rest, :global, include: ~w(disabled)

  @doc "Livebook cell-evaluation control: play-circle icon and quiet gray label."
  @spec run_button(map()) :: Phoenix.LiveView.Rendered.t()
  def run_button(assigns) do
    ~H"""
    <button type="button" class="run-button" {@rest}>
      <svg width="20" height="20" viewBox="0 0 24 24" aria-hidden="true">
        <path
          fill="currentColor"
          fill-rule="evenodd"
          d="M12 2c5.523 0 10 4.477 10 10s-4.477 10-10 10S2 17.523 2 12 6.477 2 12 2Zm-1.5 5.5v9l7-4.5-7-4.5Z"
        />
      </svg>
      <span>{@label}</span>
    </button>
    """
  end

  attr :code, :string, required: true

  @doc "Elixir source excerpt with Livebook editor-light syntax colours."
  # Makeup escapes the source text while emitting its own span markup, so the
  # raw render below cannot carry user-controlled HTML.
  # sobelow_skip ["XSS.Raw"]
  @spec code_block(map()) :: Phoenix.LiveView.Rendered.t()
  def code_block(assigns) do
    highlighted = Makeup.highlight(assigns.code, lexer: Makeup.Lexers.ElixirLexer)
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
