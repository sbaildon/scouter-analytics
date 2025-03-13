defmodule Stats.MixProject do
  use Mix.Project

  def project do
    [
      app: :stats,
      version: "0.0.0-dev",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      elixirc_options: [
        warnings_as_errors: Mix.env() == :prod
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Stats.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, github: "phoenixframework/phoenix", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons", tag: "v2.1.1", sparse: "optimized", app: false, compile: false, depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, git: "https://github.com/wojtekmach/req", ref: "5d751a0791876921afde0d23404111fbdbeb7a17", override: true},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false},
      {:objex, git: "https://git.sr.ht/~sbaildon/objex", ref: "8fad06bad1b5684b9919ceccc020662f8ea3e4b4"},
      {:typeid_elixir, "~> 1.1"},
      {:ua_inspector, "~> 3.0"},
      {:locus, "~> 2.3"},
      {:ref_inspector, "~> 2.0"},
      {:ex_cldr, "~> 2.37"},
      {:ex_cldr_territories, "~> 2.9.0"},
      {:adbc, "~> 0.7"},
      {:oban, "~> 2.19"},
      {:remote_ip, "~> 1.2"},
      {:ex_cldr_numbers, "~> 2.33"},
      {:hammer, "~> 7.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind stats", "esbuild stats"],
      "assets.deploy": [
        "tailwind stats --minify",
        "esbuild stats --minify",
        "phx.digest"
      ]
    ]
  end
end
