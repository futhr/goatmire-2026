defmodule GoatmireWeb.Layouts do
  @moduledoc """
  Root, app, and presenter layouts. Styles are hand-written static CSS under
  `priv/static/assets` rather than built through a CSS toolchain, so the
  dashboard serves from a cold checkout with `mix phx.server` and nothing else.
  """
  use GoatmireWeb, :html

  embed_templates "layouts/*"
end
