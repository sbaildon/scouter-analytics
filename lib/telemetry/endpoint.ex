defmodule Telemetry.Endpoint do
  use Plug.Router

  def init(opts) do
    Map.new(opts)
  end

  def call(conn, %{instance: instance} = opts) do
    conn |> put_private(:scouter_instance, instance) |> super(opts)
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:endpoint]

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug :match
  plug :dispatch

  post("/telemetry", to: Telemetry.EventController)
  match(_, do: send_resp(conn, 404, "not found"))
end
