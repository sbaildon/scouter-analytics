defmodule Dashboard.Routes do
  @moduledoc false
  use Dashboard, :verified_routes

  def service_url(service) do
    url(~p"/#{service}")
  end

  def root_url do
    url(~p"/")
  end

  defdelegate host, to: Dashboard.Endpoint
end
