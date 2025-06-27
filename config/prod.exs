import Config

config :logger, level: :info

config :scouter, Dashboard.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :scouter, Telemetry.Endpoint, server: true
