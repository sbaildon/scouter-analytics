import Config

config :adbc, :drivers, [:duckdb]

config :ecto_sqlite3,
  binary_id_type: :binary,
  uuid_type: :binary,
  foreign_keys: :on,
  journal_mode: :wal

config :esbuild,
  version: "0.17.11",
  stats: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :ex_cldr,
  default_locale: "en",
  default_backend: Stats.Cldr,
  json_library: JSON

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, JSON

config :stats, Dashboard.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: Dashboard.ErrorHTML, json: Dashboard.ErrorJSON],
    layout: false
  ],
  pubsub_server: Stats.PubSub

config :stats, Finch, name: Stats.Finch

config :stats, Oban,
  engine: Oban.Engines.Lite,
  queues: [default: 10],
  repo: Stats.Repo

config :stats, Stats.EventsRepo,
  migration_primary_key: [name: :id, type: :uuid, null: false],
  migration_timestamps: [type: :utc_datetime_usec]

config :stats, Stats.Repo,
  migration_primary_key: [name: :id, type: :uuid, null: false],
  migration_timestamps: [type: :utc_datetime_usec]

config :stats,
  ecto_repos: [Stats.Repo, Stats.EventsRepo],
  app_name: "Stats",
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :tailwind,
  version: "4.0.4",
  stats: [
    args: ~w(
      --input=./assets/css/app.css
      --output=./priv/static/assets/app.css
    )
  ]

config :typeid_elixir,
  default_type: :uuid

import_config "#{config_env()}.exs"
