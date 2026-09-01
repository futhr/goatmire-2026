defmodule GoatmireWeb.Router do
  @moduledoc false
  use GoatmireWeb, :router

  import BeamlensWeb.Router

  @secure_browser_headers %{
    "content-security-policy" =>
      "default-src 'self'; base-uri 'self'; connect-src 'self' ws: wss:; " <>
        "font-src 'self'; form-action 'self'; frame-ancestors 'none'; " <>
        "img-src 'self' data:; object-src 'none'; script-src 'self'; " <>
        "style-src 'self' 'unsafe-inline'"
  }

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GoatmireWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, @secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GoatmireWeb do
    pipe_through :browser

    live "/", WarehouseLive, :index
    live "/warehouse", WarehouseLive, :index
    live "/rules", RuleLive, :new
    live "/verify", VerifyLive, :index
    live "/diagnostics", DiagnosticsLive, :index
    live "/notebook", NotebookLive, :index
    live "/metrics", MetricsLive, :index
  end

  # Fullscreen presenter: deck left, live panel right. Its own root layout —
  # no topbar, slide chrome instead.
  scope "/", GoatmireWeb do
    pipe_through :browser

    get "/talk/notes/unlock/:token", SpeakerNotesController, :unlock

    live_session :talk, root_layout: {GoatmireWeb.Layouts, :presenter_root} do
      live "/talk", PresenterLive, :index
    end

    live_session :speaker_notes, root_layout: {GoatmireWeb.Layouts, :speaker_notes_root} do
      live "/talk/notes", SpeakerNotesLive, :index
    end
  end

  # Full BeamLens operator/coordinator inspector. This must live outside the
  # `GoatmireWeb`-aliased scope because the dependency owns its modules.
  scope "/" do
    pipe_through :browser
    beamlens_web("/beamlens")
  end

  # Devices that speak HTTP rather than MQTT post readings here — same event
  # shape, same engine.
  scope "/api", GoatmireWeb do
    pipe_through :api

    post "/things/:thing_id/telemetry", TelemetryController, :create
    get "/health", HealthController, :show
    post "/internal/diagnostics/v1/chat/completions", DiagnosticsCompletionController, :create
  end
end
