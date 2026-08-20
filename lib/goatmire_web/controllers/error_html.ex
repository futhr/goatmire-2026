defmodule GoatmireWeb.ErrorHTML do
  @moduledoc false
  use GoatmireWeb, :html

  @doc "Renders the standard status message for an error template."
  @spec render(String.t(), map()) :: String.t()
  def render(template, _) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
