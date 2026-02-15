import Config

alias Scouter.EventsRepo.BackupWorker

convert = fn term, as ->
  case as do
    :integer ->
      String.to_integer(term)

    :boolean ->
      String.to_existing_atom(term)

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

s3_endpoint =
  Regex.named_captures(~r/^(?<proto>.+):\/\/(?<endpoint>.+):(?<port>\d+)$/, env!.("S3_ENDPOINT"))

config :ref_inspector,
  init: {Scouter.Release, :configure_ref_inspector}

config :scouter, Admin.Endpoint, server: env_as.("ADMIN", "false", :boolean)

config :scouter, Dashboard.Endpoint,
  url: [
    host: env!.("SCOUTER_HOST"),
    port: 443,
    scheme: "https",
    path: env.("DASHBOARD_PATH", "/")
  ],
  static_url: [host: env!.("SCOUTER_HOST"), port: 443, scheme: "https", path: "/_app/analytics/static"],
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
  database: env.("EVENT_DATABASE_PATH", "/var/lib/scouter/analytics/events.duckdb"),
  pool_size: env_as.("EVENT_POOL_SIZE", "10", :integer)

config :scouter, Scouter.Repo,
  database: env.("DATABASE_PATH", "/var/lib/scouter/analytics/domain.db"),
  pool_size: env_as.("POOL_SIZE", "10", :integer)

config :scouter, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

config :ua_inspector,
  init: {Scouter.Release, :configure_ua_inspector}

if config_env() == :prod do
end
