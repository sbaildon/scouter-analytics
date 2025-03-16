import Config

config :logger, level: :info

config :stats, Telemetry.Endpoint, server: true

config :stats, Dashboard.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :swoosh, api_client: Swoosh.ApiClient.Req
config :swoosh, local: false
