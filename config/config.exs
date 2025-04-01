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
  ],
  iam: [
    args: ~w(js/iam.js --bundle --target=es2017 --outdir=../priv/static/assets/ --external:/fonts/* --external:/images/*),
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
config :stats, IAM, service_routes: Dashboard.Routes

config :stats, IAM.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: IAM.ErrorHTML, json: IAM.ErrorJSON],
    layout: false
  ],
  pubsub_server: Stats.PubSub

config :stats, Oban,
  engine: Oban.Engines.Lite,
  queues: [default: 10, mailer: 10, backups: 1],
  repo: Stats.Repo

config :stats, Stats.EventsRepo,
  migration_primary_key: [name: :id, type: :uuid, null: false],
  migration_timestamps: [type: :utc_datetime_usec]

config :stats, Stats.Repo,
  migration_primary_key: [name: :id, type: :uuid, null: false],
  migration_timestamps: [type: :utc_datetime_usec],
  service_queries_require_service_ids: true

config :stats, Telemetry.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: Telemetry.ErrorJSON],
    layout: false
  ],
  pubsub_server: Stats.PubSub

config :stats, Yemma,
  repo: Stats.Repo,
  user: IAM.User,
  token: IAM.UserToken,
  pubsub_server: Stats.PubSub

config :stats,
  ecto_repos: [Stats.Repo, Stats.EventsRepo],
  app_name: "Stats",
  edition: :commercial,
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :tailwind,
  version: "4.0.4",
  dashboard: [
    args: ~w(
      --input=./assets/css/dashboard.css
      --output=./priv/static/assets/dashboard.css
    )
  ],
  iam: [
    args: ~w(
      --input=./assets/css/iam.css
      --output=./priv/static/assets/iam.css
    )
  ]

config :typeid_elixir,
  default_type: :uuid

import_config "#{config_env()}.exs"
