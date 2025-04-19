defmodule Dashboard.AuthzPlug do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: Map.new(opts)

  def call(conn, _opts) do
    case Map.get(conn.assigns, :environment) do
      :trusted -> authorize_if_header_present(conn)
      :untrusted -> raise "untrusted environment"
      :unspecified -> conn |> build_authorization_header() |> authorize_if_header_present()
    end
  end

  defp build_authorization_header(conn) do
    {:ok, services} = Scouter.Services.list()

    service_ids =
      Enum.map_join(services, ";", fn service -> service.id end)

    put_req_header(conn, "authorization", "Plain-Text #{service_ids}")
  end

  defp authorize_if_header_present(conn) do
    case List.keyfind(conn.req_headers, "authorization", 0) do
      {_, authorization} -> authorize_session(conn, authorization)
      nil -> deauthorize_session(conn)
    end
  end

  defp authorize_session(conn, authorization), do: put_session(conn, :authorization, authorization)
  defp deauthorize_session(conn), do: delete_session(conn, :authorization)
end
