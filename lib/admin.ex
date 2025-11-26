defmodule Admin do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Admin.Endpoint, endpoint_config()}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  defp endpoint_config do
    [http: http()]
  end

  defp http do
    case :systemd.listen_fds() do
      [] -> Socket.af_inet6("ADMIN_PORT", "4004")
      fds -> Socket.socket_activation(fds, Socket.name!("ADMIN_SOCKET"))
    end
  end

  def changed(changed, _new, removed) do
    Admin.Endpoint.config_change(changed, removed)
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Phoenix.Controller
      import Phoenix.LiveView.Router

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:json]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Admin.Endpoint,
        router: Admin.Router,
        statics: []
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
