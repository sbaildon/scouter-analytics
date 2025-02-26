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

config :stats, Dashboard.Endpoint,
  url: [host: env!.("DASHBOARD_HOST"), port: 443, scheme: "https"],
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: env_as!.("DASHBOARD_PORT", :integer)
  ],
  secret_key_base: env!.("DASHBOARD_SECRET_KEY_BASE"),
  live_view: [signing_salt: env!.("DASHBOARD_SIGNING_SALT")]

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
