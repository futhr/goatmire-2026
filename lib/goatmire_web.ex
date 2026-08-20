defmodule GoatmireWeb do
  @moduledoc """
  Entrypoint definitions for the demo dashboard.

  `use GoatmireWeb, :live_view` and friends pull in the shared imports.
  """

  @doc "Static asset roots admitted by the endpoint."
  @spec static_paths() :: [String.t()]
  def static_paths, do: ~w(vendor fonts images favicon.ico robots.txt)

  @doc "Quoted imports and configuration shared by the router."
  @spec router() :: Macro.t()
  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  @doc "Quoted imports and configuration shared by channels."
  @spec channel() :: Macro.t()
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  @doc "Quoted imports and configuration shared by controllers."
  @spec controller() :: Macro.t()
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: GoatmireWeb.Layouts]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  @doc "Quoted imports and configuration shared by LiveViews."
  @spec live_view() :: Macro.t()
  def live_view do
    quote do
      use Phoenix.LiveView, layout: {GoatmireWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  @doc "Quoted imports and configuration shared by LiveComponents."
  @spec live_component() :: Macro.t()
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @doc "Quoted imports and configuration shared by HTML components."
  @spec html() :: Macro.t()
  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller, only: [get_csrf_token: 0]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import GoatmireWeb.CoreComponents

      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  @doc "Quoted verified-route configuration for web modules."
  @spec verified_routes() :: Macro.t()
  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: GoatmireWeb.Endpoint,
        router: GoatmireWeb.Router,
        statics: GoatmireWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
