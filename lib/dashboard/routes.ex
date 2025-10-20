defmodule Dashboard.Routes do
  @moduledoc false
  use Dashboard, :verified_routes

  def root_url(query \\ []) do
    URI
    |> struct(Dashboard.Endpoint.config(:url))
    |> URI.append_query(URI.encode_query(query, :rfc3986))
  end

  defdelegate host, to: Dashboard.Endpoint
end
