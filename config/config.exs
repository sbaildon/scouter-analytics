import Config

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

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, JSON

config :stats, Finch, name: Stats.Finch

config :stats, Stats.Repo,
  migration_primary_key: [name: :id, type: :uuid, null: false],
  migration_timestamps: [type: :utc_datetime_usec]

config :stats, StatsWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: StatsWeb.ErrorHTML, json: StatsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Stats.PubSub

config :stats,
  ecto_repos: [Stats.Repo],
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

import_config "#{config_env()}.exs"
