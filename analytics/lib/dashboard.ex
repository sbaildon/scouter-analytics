defmodule Dashboard do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Dashboard.Telemetry,
      {Dashboard.Endpoint, endpoint_config()},
      {Dashboard.RateLimit, clean_period: to_timeout(minute: 10)}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  defp endpoint_config do
    [http: http()]
  end

  defp http do
    case :systemd.listen_fds() do
      [] -> Socket.af_inet6("DASHBOARD_PORT", "4000")
      fds -> Socket.socket_activation(fds, Socket.name!("DASHBOARD_SOCKET"))
    end
  end

  def changed(changed, _new, removed) do
    Dashboard.Endpoint.config_change(changed, removed)
  end

  def static_paths, do: ~w(assets js css images favicon.ico robots.txt)
  # def object_paths, do: ~w(fonts)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Phoenix.Controller
      import Phoenix.LiveView.Router

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: Dashboard.Layouts]

      use Gettext, backend: Dashboard.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {Dashboard.Layouts, :app}

      import LiveHelpers

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: Dashboard.Gettext

      import Dashboard.CoreComponents
      import Dashboard.StatComponents

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Dashboard.Endpoint,
        router: Dashboard.Router,
        statics: Dashboard.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
