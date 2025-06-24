import Config

config :ecto_sqlite3,
  uuid_type: :string

config :logger, :default_formatter, format: "$metadata[$level] $message\n", metadata: [:module]

config :phoenix,
  plug_init_mode: :runtime,
  stacktrace_depth: 20

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

config :scouter, Dashboard.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:dashboard, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:dashboard, ~w(--watch)]}
  ],
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/dashboard/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :scouter, Scouter.EventsRepo,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  log: false

config :scouter, Scouter.Repo,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :scouter, Telemetry.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/gettext/.*(po)$",
      ~r"lib/api/(controllers|components)/.*(ex|heex)$"
    ]
  ]

config :scouter, dev_routes: true

config :swoosh, :api_client, false

config :typeid_elixir,
  default_type: :string

with {:ok, object_storage_url} <- System.fetch_env("MINIO_API_HOST") do
  config :scouter, Finch,
    pools: %{
      "https://#{object_storage_url}" => [
        conn_opts: [
          transport_opts: [
            verify: :verify_none
          ]
        ]
      ]
    }
end
