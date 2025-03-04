import Config

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
  System.fetch_env!(var)
end

env_lazy! = fn var, fallback_var ->
  case System.fetch_env(var) do
    :error -> System.fetch_env!(fallback_var)
    {:ok, value} -> value
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

reject_unless_prefixed = fn enum ->
  Enum.filter(enum, fn {k, _v} -> String.starts_with?(k, "HTTPFS_") end)
end

remove_prefix_and_group_by_name = fn enum ->
  Enum.reduce(enum, %{}, fn {k, v}, acc ->
    %{"name" => name, "rest" => rest} = Regex.named_captures(~r/^(?<prefix>HTTPFS)_(?<name>[A-Za-z0-9]+)_(?<rest>.+)$/, k)
    Map.update(acc, name, [{rest, v}], fn existing -> [{rest, v} | existing] end)
  end)
end

httpfs_credentials = fn ->
  System.get_env()
  |> reject_unless_prefixed.()
  |> remove_prefix_and_group_by_name.()
end

config :stats, Dashboard.Endpoint,
  url: [host: env!.("DASHBOARD_HOST"), port: 443, scheme: "https"],
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: env_as!.("DASHBOARD_PORT", :integer)
  ],
  secret_key_base: env!.("DASHBOARD_SECRET_KEY_BASE"),
  live_view: [signing_salt: env!.("DASHBOARD_SIGNING_SALT")]

config :stats, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {env.("BACKUP_SCHEDULE", "05 4 * * 2"), Stats.EventsRepo.BackupWorker}
     ]}
  ]

config :stats, Objex,
  access_key_id: env!.("AWS_ACCESS_KEY_ID"),
  secret_access_key: env!.("AWS_SECRET_KEY"),
  proto: Map.fetch!(s3_endpoint, "proto"),
  endpoint: Map.fetch!(s3_endpoint, "endpoint"),
  port: Map.fetch!(s3_endpoint, "port"),
  region: env.("AWS_REGION", "auto"),
  http_client: {Finch, name: Stats.Finch}

config :stats, Stats.EventsRepo,
  database: env!.("EVENT_DATABASE_PATH"),
  httpfs_credentials: httpfs_credentials.(),
  pool_size: 1

config :stats, Stats.Geo,
  database: Path.join([".", "/"] ++ Path.wildcard("./priv/mmdb/*.mmdb")),
  maxmind_opts: [
    license_key: env.("API_KEY_MAXMIND", nil)
  ]

config :stats, Stats.Repo,
  database: env!.("DATABASE_PATH"),
  pool_size: env_as.("POOL_SIZE", "10", :integer)

config :stats, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

if config_env() == :prod do
  config :stats, Stats.Mailer,
    adapter: Swoosh.Adapters.Postmark,
    api_key: env!.("API_KEY_POSTMARK")
end
