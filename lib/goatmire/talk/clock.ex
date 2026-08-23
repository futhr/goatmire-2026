defmodule Goatmire.Talk.Clock do
  @moduledoc """
  Wall-clock authority for the `/talk` presenter.

  Owns slide position, per-slide elapsed time, panel state, and the budget
  table from `priv/talk/timings.exs`. It lives in its own supervision branch
  and checkpoints position to `Goatmire.Talk.Store` plus an optional file, so
  a LiveView crash, a browser refresh, or a full node restart resumes the
  talk exactly where it stopped. One snapshot per second is broadcast on
  `topic/0`; every mutation broadcasts immediately.
  """

  use GenServer

  alias Goatmire.Config
  alias Goatmire.Talk.Store

  @topic "talk:clock"
  @tick_ms 1_000
  @slide_count 25
  @default_budget_seconds 60
  @panels [:split, :deck_full, :live_full]
  @tabs [:code, :warehouse, :rules, :diagnostics, :verify, :notebook, :metrics]

  @typedoc "A right-panel pane the presenter can show."
  @type tab :: :code | :warehouse | :rules | :diagnostics | :verify | :notebook | :metrics

  @typedoc "One broadcast frame: everything the presenter chrome renders."
  @type snapshot :: %{
          slide: pos_integer(),
          slide_count: pos_integer(),
          started?: boolean(),
          talk_elapsed_s: non_neg_integer(),
          slide_elapsed_s: non_neg_integer(),
          slide_budget_s: pos_integer(),
          slide_overtime_s: non_neg_integer(),
          overtime_ratio: float(),
          drift_s: integer(),
          panel: :split | :deck_full | :live_full,
          tab: tab(),
          slide_tab: tab() | nil,
          reveal_panel: :split | :deck_full | :live_full,
          zoom: float(),
          budget_total_s: non_neg_integer(),
          slot_s: pos_integer(),
          warnings: [String.t()]
        }

  @doc "Starts the presenter clock."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "PubSub topic carrying `{:talk_clock, snapshot}` frames."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc "Returns the current snapshot without mutating anything."
  @spec snapshot() :: snapshot()
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  @doc "Starts the talk clock at the current slide; a no-op when already running."
  @spec start_talk() :: snapshot()
  def start_talk, do: GenServer.call(__MODULE__, :start_talk)

  @doc "Advances one slide, starting the talk clock on first use."
  @spec next() :: snapshot()
  def next, do: GenServer.call(__MODULE__, :next)

  @doc "Steps one slide back."
  @spec prev() :: snapshot()
  def prev, do: GenServer.call(__MODULE__, :prev)

  @doc "Jumps to a slide, applying that slide's configured panel and tab."
  @spec goto(pos_integer()) :: snapshot()
  def goto(slide) when is_integer(slide) and slide in 1..@slide_count do
    GenServer.call(__MODULE__, {:goto, slide})
  end

  @doc """
  Opens the right panel at this slide's configured layout.

  Slides always enter deck-only so the room reads the claim before the
  evidence; revealing is a deliberate act.
  """
  @spec reveal() :: snapshot()
  def reveal, do: GenServer.call(__MODULE__, :reveal)

  @doc "Overrides the panel layout until the next slide change."
  @spec set_panel(:split | :deck_full | :live_full) :: snapshot()
  def set_panel(panel) when panel in @panels, do: GenServer.call(__MODULE__, {:set_panel, panel})

  @doc "Selects the right-panel tab."
  @spec set_tab(tab()) :: snapshot()
  def set_tab(tab) when tab in @tabs, do: GenServer.call(__MODULE__, {:set_tab, tab})

  @doc "Steps presenter text zoom up or down, clamped to 0.7–1.5."
  @spec zoom(:in | :out) :: snapshot()
  def zoom(direction) when direction in [:in, :out] do
    GenServer.call(__MODULE__, {:zoom, direction})
  end

  @doc "Restarts the timer in place: elapsed cleared, slide and layout kept."
  @spec reset_clock() :: snapshot()
  def reset_clock, do: GenServer.call(__MODULE__, :reset_clock)

  @doc "Clears clock state and persisted position; timings stay loaded."
  @spec reset() :: snapshot()
  def reset, do: GenServer.call(__MODULE__, :reset)

  @doc "Re-reads `priv/talk/timings.exs` without touching talk position."
  @spec reload_timings() :: snapshot()
  def reload_timings, do: GenServer.call(__MODULE__, :reload_timings)

  @impl true
  def init(opts) do
    {timings, slot, warnings} = load_timings()

    state =
      %{
        timings: timings,
        slot_seconds: slot,
        warnings: warnings,
        slide: 1,
        started_at_ms: nil,
        entered_at_ms: nil,
        accumulated_ms: %{},
        panel: :split,
        tab: :warehouse,
        zoom: 1.0
      }
      |> restore_saved()

    if Keyword.get(opts, :tick, true), do: schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_call(:snapshot, _, state), do: {:reply, build_snapshot(state), state}

  def handle_call(:start_talk, _, state) do
    state = if state.started_at_ms, do: state, else: start_now(state)
    mutate(state)
  end

  def handle_call(:next, _, state),
    do: mutate(change_slide(state, min(state.slide + 1, @slide_count)))

  def handle_call(:prev, _, state), do: mutate(change_slide(state, max(state.slide - 1, 1)))
  def handle_call({:goto, slide}, _, state), do: mutate(change_slide(state, slide))
  def handle_call({:set_panel, panel}, _, state), do: mutate(%{state | panel: panel})

  def handle_call(:reveal, _, state) do
    mutate(%{state | panel: slide_timing(state).panel})
  end

  def handle_call({:set_tab, tab}, _, state), do: mutate(%{state | tab: tab})

  def handle_call({:zoom, direction}, _, state) do
    step = if direction == :in, do: 0.1, else: -0.1
    zoom = Float.round(min(max(state.zoom + step, 0.7), 1.5), 1)
    mutate(%{state | zoom: zoom})
  end

  def handle_call(:reset_clock, _, state) do
    now = if state.slide >= 2, do: now_ms()
    mutate(%{state | started_at_ms: now, entered_at_ms: now, accumulated_ms: %{}})
  end

  def handle_call(:reset, _, state) do
    Store.clear()

    with path when is_binary(path) <- Config.talk_state_path(), do: File.rm(path)

    %{
      state
      | slide: 1,
        started_at_ms: nil,
        entered_at_ms: nil,
        accumulated_ms: %{},
        panel: :split,
        tab: :warehouse,
        zoom: 1.0
    }
    |> apply_timing_defaults()
    |> mutate()
  end

  def handle_call(:reload_timings, _, state) do
    {timings, slot, warnings} = load_timings()
    mutate(%{state | timings: timings, slot_seconds: slot, warnings: warnings})
  end

  @impl true
  def handle_info(:tick, state) do
    schedule_tick()
    broadcast(state)
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp mutate(state) do
    persist(state)
    broadcast(state)
    {:reply, build_snapshot(state), state}
  end

  defp change_slide(state, slide) do
    state = accumulate_current(state)

    # Slide 1 is the holding slide while the room settles; the wall clock
    # starts the first time the deck reaches slide 2.
    state =
      if slide >= 2 and is_nil(state.started_at_ms), do: start_now(state), else: state

    timing = Map.get(state.timings, slide, default_timing())

    %{
      state
      | slide: slide,
        entered_at_ms: now_ms(),
        panel: :deck_full,
        tab: timing.tab || state.tab
    }
  end

  defp start_now(state), do: %{state | started_at_ms: now_ms(), entered_at_ms: now_ms()}

  defp accumulate_current(%{started_at_ms: nil} = state), do: state

  defp accumulate_current(state) do
    spent = now_ms() - state.entered_at_ms
    accumulated = Map.update(state.accumulated_ms, state.slide, spent, &(&1 + spent))
    %{state | accumulated_ms: accumulated}
  end

  defp build_snapshot(state) do
    now = now_ms()
    timing = Map.get(state.timings, state.slide, default_timing())
    budget = timing.seconds

    talk_elapsed = if state.started_at_ms, do: div(now - state.started_at_ms, 1000), else: 0

    slide_elapsed_ms =
      Map.get(state.accumulated_ms, state.slide, 0) +
        if(state.started_at_ms, do: now - state.entered_at_ms, else: 0)

    slide_elapsed = div(slide_elapsed_ms, 1000)

    planned_start =
      Enum.reduce(1..@slide_count, 0, fn n, acc ->
        if n < state.slide,
          do: acc + Map.get(state.timings, n, default_timing()).seconds,
          else: acc
      end)

    %{
      slide: state.slide,
      slide_count: @slide_count,
      started?: not is_nil(state.started_at_ms),
      talk_elapsed_s: talk_elapsed,
      slide_elapsed_s: slide_elapsed,
      slide_budget_s: budget,
      slide_overtime_s: max(slide_elapsed - budget, 0),
      overtime_ratio: if(budget > 0, do: slide_elapsed / budget, else: 0.0),
      drift_s: talk_elapsed - planned_start - min(slide_elapsed, budget),
      panel: state.panel,
      tab: state.tab,
      slide_tab: timing.tab,
      reveal_panel: timing.panel,
      zoom: state.zoom,
      budget_total_s: Enum.sum(Enum.map(Map.values(state.timings), & &1.seconds)),
      slot_s: state.slot_seconds,
      warnings: state.warnings
    }
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(Goatmire.PubSub, @topic, {:talk_clock, build_snapshot(state)})
  end

  defp persist(state) do
    saved =
      Map.take(state, [
        :slide,
        :started_at_ms,
        :entered_at_ms,
        :accumulated_ms,
        :panel,
        :tab,
        :zoom
      ])

    Store.put(saved)

    with path when is_binary(path) <- Config.talk_state_path() do
      File.mkdir_p(Path.dirname(path))
      File.write(path, :erlang.term_to_binary(saved))
    end

    state
  end

  defp restore_saved(state) do
    saved = Store.get() || read_saved_file()

    case saved do
      %{slide: slide} = saved when slide in 1..@slide_count ->
        state = Map.merge(state, saved)
        # A mid-talk restart keeps the presenter's manual layout; before the
        # talk starts, the slide's configured layout always wins over a stale
        # checkpoint.
        if state.started_at_ms, do: state, else: apply_timing_defaults(state)

      _ ->
        apply_timing_defaults(state)
    end
  end

  defp apply_timing_defaults(state) do
    timing = slide_timing(state)
    %{state | panel: :deck_full, tab: timing.tab || state.tab}
  end

  defp slide_timing(state), do: Map.get(state.timings, state.slide, default_timing())

  defp read_saved_file do
    with path when is_binary(path) <- Config.talk_state_path(),
         {:ok, binary} <- File.read(path) do
      :erlang.binary_to_term(binary, [:safe])
    else
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp load_timings do
    path = Path.join(Application.app_dir(:goatmire, "priv"), "talk/timings.exs")

    try do
      {%{slot_seconds: slot, slides: slides}, _} = Code.eval_file(path)
      normalize_timings(slides, slot)
    rescue
      error ->
        {default_timings(), 1_800,
         [
           "timings unreadable (#{Exception.message(error)}); every slide gets #{@default_budget_seconds}s"
         ]}
    end
  end

  defp normalize_timings(slides, slot) do
    entries =
      Map.new(slides, fn
        {n, seconds} -> {n, %{seconds: seconds, panel: :split, tab: nil}}
        {n, seconds, opts} -> {n, normalize_entry(seconds, opts)}
      end)

    timings = Map.merge(default_timings(), Map.take(entries, Enum.to_list(1..@slide_count)))

    missing = Enum.filter(1..@slide_count, &(!Map.has_key?(entries, &1)))
    total = Enum.sum(Enum.map(Map.values(timings), & &1.seconds))

    warnings =
      List.flatten([
        if(missing != [],
          do: [
            "no budget for slides #{Enum.join(missing, ", ")}; defaulting to #{@default_budget_seconds}s"
          ],
          else: []
        ),
        if(total > slot,
          do: ["budgets total #{total}s, #{total - slot}s over the #{slot}s slot"],
          else: []
        )
      ])

    {timings, slot, warnings}
  end

  defp normalize_entry(seconds, opts) do
    panel = Keyword.get(opts, :panel, :split)
    tab = Keyword.get(opts, :tab)

    %{
      seconds: seconds,
      panel: if(panel in @panels, do: panel, else: :split),
      tab: if(tab in @tabs, do: tab, else: nil)
    }
  end

  defp default_timing, do: %{seconds: @default_budget_seconds, panel: :split, tab: nil}
  defp default_timings, do: Map.new(1..@slide_count, &{&1, default_timing()})
  defp now_ms, do: System.system_time(:millisecond)
  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_ms)
end
