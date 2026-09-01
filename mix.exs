defmodule Goatmire.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :goatmire,
      version: "0.2.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      listeners: [Phoenix.CodeReloader],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases(),
      dialyzer: [plt_add_apps: [:mix]],
      test_coverage: [tool: ExCoveralls],
      coveralls: [minimum_coverage: 70]
    ]
  end

  def cli do
    [
      preferred_envs: [
        check: :test,
        quality: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.github": :test,
        "coveralls.html": :test,
        "test.unit": :test,
        "test.all": :test,
        "test.e2e": :test,
        "test.llm": :test,
        "test.property": :test,
        "test.stress": :test,
        "test.soak": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :inets, :ssl],
      mod: {Goatmire.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.11"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_live_view, "~> 1.2.11"},
      {:bandit, "~> 1.12"},
      {:phoenix_live_reload, "~> 1.7", only: :dev},
      {:tortoise311, "~> 0.12"},
      {:req, "~> 0.7.4"},
      {:finch, "~> 0.23"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.4"},
      {:telemetry_metrics, "~> 1.2"},
      # `_core` rather than the full `telemetry_metrics_prometheus`: the latter
      # bundles its own Cowboy server to serve one text endpoint. Bandit is
      # already here for Phoenix, so `Goatmire.Metrics.Exporter` serves the
      # scrape instead — one web server in the tree, not two.
      {:telemetry_metrics_prometheus_core, "~> 1.1"},
      {:telemetry_poller, "~> 1.1"},
      {:observer_cli, "~> 2.0"},
      # Exact while the BeamLens web package is beta and its API is evolving.
      {:beamlens, "== 0.3.1"},
      # Fork of 0.1.0-beta.4 adding consumer theming; PR-able upstream.
      git_or_local(
        :beamlens_web,
        "https://github.com/futhr/beamlens_web.git",
        "../beamlens_web",
        ref: "a8bcb2340d9a67cb91265d929f0f286d3425ad24"
      ),
      {:ex_maude, "~> 0.4.1"},

      # Renders the verifier's rule terms with Livebook editor colours.
      {:makeup_elixir, "~> 1.0"},

      # Plug is a transitive runtime dependency of Phoenix; it cannot be
      # `only: :test` even though the test suite is what uses it directly.
      {:plug, "~> 1.20"},
      {:lazy_html, "~> 0.1.12", only: :test},
      {:stream_data, "~> 1.4", only: :test},
      {:wallaby, "~> 0.31.0", only: :test, runtime: false},
      {:benchee, "~> 1.5", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:oeditus_credo, "~> 0.11.2", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.15.0", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.23", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      test: ["test --warnings-as-errors"],
      "test.unit": ["test --only unit"],
      "test.all": ["test"],
      "test.e2e": ["test --warnings-as-errors --only e2e test/e2e"],
      "test.llm": ["test --only llm test/llm"],
      "test.property": ["test test/property"],
      "test.stress": ["test --only stress test/stress"],
      "test.soak": ["test --only soak test/stress"],
      quality: ["check"]
    ]
  end

  defp releases do
    [
      goatmire: [
        include_executables_for: [:unix],
        applications: [goatmire: :permanent]
      ]
    ]
  end

  defp git_or_local(dep, git_url, local_path, opts) do
    if File.dir?(local_path) do
      {dep, path: local_path}
    else
      {dep, Keyword.merge(opts, git: git_url)}
    end
  end
end
