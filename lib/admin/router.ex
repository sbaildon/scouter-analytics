defmodule Admin.Router do
  use Admin, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/admin", Admin do
    pipe_through [:api]

    post "/service", APIController, :service
  end
end
