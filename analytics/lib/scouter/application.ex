defmodule Scouter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Scouter.Repo,
      Scouter.Writer,
      Scouter.EventsRepo,
      {Oban, Application.fetch_env!(:scouter, Oban)},
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

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, new, removed) do
    Dashboard.changed(changed, new, removed)
    :ok
  end

  defp skip_migrations? do
    if System.get_env("RUN_MIGRATIONS"), do: false, else: true
  end
end
