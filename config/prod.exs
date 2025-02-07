import Config

config :logger, level: :info

config :stats, StatsWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

config :swoosh, api_client: Swoosh.ApiClient.Req
config :swoosh, local: false
