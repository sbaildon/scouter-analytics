defmodule Dashboard.HealthController do
  use Dashboard, :controller

  def check(conn, _opts) do
    text(conn, "ok")
  end
end
