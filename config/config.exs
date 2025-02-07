# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  stats: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, JSON

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :stats, Stats.Mailer, adapter: Swoosh.Adapters.Local

# Configures the endpoint
config :stats, StatsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: StatsWeb.ErrorHTML, json: StatsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Stats.PubSub,
  live_view: [signing_salt: "NGGMhL/n"]

config :stats,
  ecto_repos: [Stats.Repo],
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
