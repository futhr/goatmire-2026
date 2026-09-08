defmodule GoatmireWeb.E2ECase do
  @moduledoc """
  PhoenixTest case template for Playwright-driven browser tests.

  Each test gets an isolated browser context against the real loopback endpoint.
  Pass Playwright case options such as `:browser_context_opts` or `:parameterize`
  through `use GoatmireWeb.E2ECase`.
  """

  use ExUnit.CaseTemplate

  using opts do
    quote do
      use PhoenixTest.Playwright.Case, unquote(opts)

      @endpoint GoatmireWeb.Endpoint
    end
  end
end
