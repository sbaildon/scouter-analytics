defmodule Dashboard.Routes do
  @moduledoc false
  use Dashboard, :verified_routes

  def service_url(service) do
    url(~p"/#{service}")
  end

  def root_url do
    struct(URI, Dashboard.Endpoint.config(:url))
  end

  defdelegate host, to: Dashboard.Endpoint
end
