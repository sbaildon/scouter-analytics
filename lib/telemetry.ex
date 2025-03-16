defmodule Telemetry do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Telemetry.Telemetry,
      Telemetry.Endpoint
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
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

      use Gettext, backend: Telemetry.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Telemetry.Endpoint,
        router: Telemetry.Router,
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
