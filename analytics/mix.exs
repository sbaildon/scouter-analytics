defmodule Scouter.MixProject do
  use Mix.Project

  def project do
    [
      app: :scouter,
      version: "0.0.0-dev",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      elixirc_options: [
        warnings_as_errors: Mix.env() == :prod
      ],
      releases: [
        scouter: [
          include_executables_for: [:unix]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Scouter.Application, []},
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
      {:postgrex, ">= 0.0.0"},
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
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false},
      {:objex, git: "https://git.sr.ht/~sbaildon/objex", ref: "9c0e92ff38850b0b2ec2847afac004ea4f713540"},
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
      {:hammer, "~> 7.0"},
      {:cachex, "~> 4.0"},
      {:gen_stage, "~> 1.2"},
      {:broadway, "~> 1.2"},
      {:broadway_dashboard, "~> 0.4", only: [:dev, :test]},
      {:referrer_blocklist, git: "https://github.com/sbaildon/referrer-blocklist"},
      {:cidr, "~> 1.2"}
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
      "assets.build": ["tailwind dashboard", "esbuild dashboard"],
      "assets.deploy": [
        "tailwind dashboard --minify",
        "esbuild dashboard --minify",
        "phx.digest"
      ]
    ]
  end
end
