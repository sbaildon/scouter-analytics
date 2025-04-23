defmodule Scouter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl Application
  def start(_type, _args) do
    children = [
      Scouter.Repo,
      Scouter.Writer,
      Scouter.EventsRepo,
      {Oban, oban_config(:scouter)},
      {ReferrerBlocklist, [http_client: Req]},
      Scouter.Services,
      Telemetry,
      Dashboard,
      {Scouter.Geo, Application.fetch_env!(:scouter, Scouter.Geo)},
      {Finch, Application.fetch_env!(:scouter, Finch)},
      {Ecto.Migrator, repos: Application.fetch_env!(:scouter, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:scouter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Scouter.PubSub}
      # {Objex, Application.fetch_env!(:scouter, Objex)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Scouter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def start_phase(:post_start, :normal, _args) do
    :systemd.unset_env(:listen_fds)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, new, removed) do
    Dashboard.changed(changed, new, removed)
    :ok
  end

  defp oban_config(otp_app) do
    config = Application.fetch_env!(otp_app, Oban)

    config
    |> Keyword.fetch!(:plugins)
    |> List.keyfind(Oban.Plugins.Cron, 0)
    |> elem(1)
    |> Keyword.get(:crontab)
    |> case do
      [] -> Logger.warning("backups disabled. no configuration provided")
      _ -> nil
    end

    config
  end

  defp skip_migrations? do
    if System.get_env("RUN_MIGRATIONS"), do: false, else: true
  end
end
