defmodule Dashboard.Router do
  use Dashboard, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug Dashboard.TrustedProxiesPlug
    plug :fetch_live_flash
    plug :put_root_layout, html: {Dashboard.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :static
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authz do
    plug Dashboard.FromPlug
    plug Dashboard.AuthzPlug
  end

  scope "/", Dashboard do
    pipe_through [:browser, :authz]

    live_session :default, on_mount: Dashboard.InitAssigns do
      live "/", StatsLive, :index

      if Application.compile_env(:scouter, :edition) == :commercial do
        live "/:service", StatsLive, :service
      end
    end
  end

  if Application.compile_env(:scouter, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard",
        metrics: Dashboard.Telemetry,
        additional_pages: [
          broadway: {BroadwayDashboard, pipelines: [Telemetry.Broadway]}
        ]
    end
  end

  def static(conn, _opts) do
    put_static_url(conn, URI |> struct(Dashboard.Endpoint.config(:url)) |> URI.append_path("/static"))
  end
end
