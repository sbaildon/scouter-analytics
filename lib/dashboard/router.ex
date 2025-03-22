defmodule Dashboard.Router do
  use Dashboard, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Dashboard.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Dashboard do
    pipe_through :browser

    live "/", StatsLive, :index

    if Application.compile_env(:stats, :edition) == :commercial do
      live "/:service", StatsLive, :service
    end
  end

  if Application.compile_env(:stats, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: Dashboard.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
