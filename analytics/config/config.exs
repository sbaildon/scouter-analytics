import Config

config :adbc, :drivers, [:duckdb]

config :ecto_sqlite3,
  binary_id_type: :binary,
  uuid_type: :binary,
  foreign_keys: :on,
  journal_mode: :wal

config :esbuild,
  version: "0.17.11",
  dashboard: [
    args:
      ~w(js/dashboard.js --bundle --target=es2017 --outdir=../priv/static/assets/ --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :ex_cldr,
  default_locale: "en",
  default_backend: Scouter.Cldr,
  json_library: JSON

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, JSON

config :scouter, Dashboard.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: Dashboard.ErrorHTML, json: Dashboard.ErrorJSON],
    layout: false
  ],
  pubsub_server: Scouter.PubSub

config :scouter, Finch, name: Scouter.Finch

config :scouter, Oban,
  engine: Oban.Engines.Lite,
  queues: [default: 10, mailer: 10, backups: 1],
  repo: Scouter.Repo

config :scouter, Scouter.EventsRepo,
  migration_primary_key: [name: :id, type: :uuid, null: false],
  migration_timestamps: [type: :utc_datetime_usec]

config :scouter, Scouter.Repo,
  migration_primary_key: [name: :id, type: :uuid, null: false],
  migration_timestamps: [type: :utc_datetime_usec]

config :scouter, Telemetry.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: Telemetry.ErrorJSON],
    layout: false
  ],
  pubsub_server: Scouter.PubSub

config :scouter,
  ecto_repos: [Scouter.Repo, Scouter.EventsRepo],
  app_name: "Scouter",
  edition: :commercial,
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :tailwind,
  version: "4.1.3",
  dashboard: [
    args: ~w(
      --input=./assets/css/dashboard.css
      --output=./priv/static/assets/dashboard.css
    )
  ]

config :typeid_elixir,
  default_type: :uuid

import_config "#{config_env()}.exs"
