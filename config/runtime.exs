import Config

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

credential = fn env, size, file ->
  operator_configured_path = Path.join([System.get_env("CREDENTIALS_DIRECTORY", "/run/secrets"), file])
  fallback_path = Path.join([System.get_env("STATE_DIRECTORY", "/var/lib/scouter/analytics"), "credentials", file])

  cond do
    value = System.get_env(env) ->
      value

    File.exists?(operator_configured_path) ->
      File.read!(operator_configured_path)

    File.exists?(fallback_path) ->
      File.read!(fallback_path)

    true ->
      secret = :crypto.strong_rand_bytes(size) |> Base.encode64()
      File.mkdir_p!(Path.dirname(fallback_path))
      File.write!(fallback_path, secret)
      secret
  end
end

config :ref_inspector,
  init: {Scouter.Release, :configure_ref_inspector}

config :scouter, Admin.Endpoint, server: env_as.("ADMIN", "false", :boolean)

config :scouter, Dashboard.Endpoint,
  url: [
    host: env.("SCOUTER_HOST", nil),
    port: 443,
    scheme: "https",
    path: env.("DASHBOARD_PATH", "/")
  ],
  static_url: [host: env.("SCOUTER_HOST", nil), port: 443, scheme: "https", path: "/_app/analytics/static"],
  secret_key_base: credential.("DASHBOARD_SECRET_KEY_BASE", 64, "dashboard_secret_key_base"),
  live_view: [signing_salt: credential.("DASHBOARD_SIGNING_SALT", 32, "dashboard_signing_salt")],
  trusted_proxies: System.get_env("TRUSTED_PROXIES")

config :scouter, Scouter.EventsRepo,
  database: env.("EVENT_DATABASE_PATH", "/var/lib/scouter/analytics/events.duckdb"),
  pool_size: env_as.("EVENT_POOL_SIZE", "1", :integer)

config :scouter, Scouter.Repo,
  database: env.("DATABASE_PATH", "/var/lib/scouter/analytics/domain.db"),
  pool_size: env_as.("POOL_SIZE", "10", :integer)

config :scouter, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

config :ua_inspector,
  init: {Scouter.Release, :configure_ua_inspector}

if config_env() == :prod do
end
