defmodule GoatmireWeb.Layouts do
  @moduledoc """
  Root and app layouts. Styles are inlined rather than built through a CSS
  toolchain, so the dashboard serves from a cold checkout with `mix phx.server`
  and nothing else.
  """
  use GoatmireWeb, :html

  embed_templates "layouts/*"
end
