import Config

alias Scouter.EventsRepo.BackupWorker

convert = fn term, as ->
  case as do
    :integer ->
      String.to_integer(term)

    _ ->
      raise """
      unknown cast, #{as}, for #{term}
      """
  end
end

env! = fn var ->
  case System.fetch_env(var) do
    {:ok, env} ->
      env

    :error ->
      IO.puts(:stderr, "#{inspect(var)} envrionment is not set")
      System.halt(1)
  end
end

env = fn var, default ->
  System.get_env(var, default)
end

env_as! = fn var, as ->
  env = env!.(var)
  convert.(env, as)
end

env_as = fn var, default, as ->
  env = env.(var, default)
  convert.(env, as)
end

# s3_endpoint =
#   Regex.named_captures(~r/^(?<proto>.+):\/\/(?<endpoint>.+):(?<port>\d+)$/, env!.("S3_ENDPOINT"))

config :ref_inspector,
  init: {Scouter.Release, :configure_ref_inspector}

config :scouter, Dashboard.Endpoint,
  url: [host: env!.("DASHBOARD_HOST"), port: 443, scheme: "https"],
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: env_as.("DASHBOARD_PORT", "4000", :integer)
  ],
  secret_key_base: env!.("DASHBOARD_SECRET_KEY_BASE"),
  live_view: [signing_salt: env!.("DASHBOARD_SIGNING_SALT")],
  trusted_proxies: System.get_env("TRUSTED_PROXIES")

config :scouter, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab:
       Enum.map(BackupWorker.config(), fn {name, options} ->
         {Map.fetch!(options, "SCHEDULE"), BackupWorker, args: %{name: name}}
       end)}
  ]

config :scouter, Scouter.EventsRepo,
  database: env.("EVENT_DATABASE_PATH", "/var/lib/scouter/events.duckdb"),
  pool_size: 1

# config :scouter, Objex,
#   access_key_id: env!.("AWS_ACCESS_KEY_ID"),
#   secret_access_key: env!.("AWS_SECRET_KEY"),
#   proto: Map.fetch!(s3_endpoint, "proto"),
#   endpoint: Map.fetch!(s3_endpoint, "endpoint"),
#   port: Map.fetch!(s3_endpoint, "port"),
#   region: env.("AWS_REGION", "auto"),
#   http_client: {Finch, name: Scouter.Finch}

config :scouter, Scouter.Geo, database: env.("MMDB_PATH", nil)

config :scouter, Scouter.Repo,
  database: env.("DATABASE_PATH", "/var/lib/scouter/service.db"),
  pool_size: env_as.("POOL_SIZE", "1", :integer)

config :scouter, Telemetry.Endpoint,
  url: [host: env!.("TELEMETRY_HOST"), port: 443, scheme: "https"],
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: env_as.("TELEMETRY_PORT", "4001", :integer)
  ],
  secret_key_base: env!.("TELEMETRY_SECRET_KEY_BASE")

config :scouter, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

config :ua_inspector,
  init: {Scouter.Release, :configure_ua_inspector}

if config_env() == :prod do
  config :scouter, Scouter.Mailer,
    adapter: Swoosh.Adapters.Postmark,
    api_key: env!.("API_KEY_POSTMARK")
end
