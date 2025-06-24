defmodule Telemetry.Router do
  use Telemetry, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Telemetry do
    pipe_through :api

    post "/telemetry", EventController, :record
  end
end
