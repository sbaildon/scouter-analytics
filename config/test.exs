import Config

alias Ecto.Adapters.SQL.Sandbox

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :scouter, Dashboard.Endpoint, server: false
config :scouter, Scouter.EventsRepo, pool: Sandbox
config :scouter, Scouter.Repo, pool: Sandbox
