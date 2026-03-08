defmodule Scouter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl Application
  def start(_type, _args) do
    children = [
      {ReferrerBlocklist, [http_client: Req]},
      {Phoenix.PubSub, name: Scouter.PubSub},
      Scouter.Instances,
      Scouter.Services,
      Telemetry.Broadway,
      Dashboard,
      Admin,
      {Finch, Application.fetch_env!(:scouter, Finch)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Scouter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def start_phase(:post_start, :normal, _args) do
    :systemd.unset_env(:listen_fds)
    :systemd.notify(:ready)
    Logger.info("notified systemd")
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, new, removed) do
    Dashboard.changed(changed, new, removed)
    :ok
  end
end
