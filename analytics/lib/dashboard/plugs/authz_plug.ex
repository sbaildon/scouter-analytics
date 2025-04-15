defmodule Dashboard.AuthzPlug do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: Map.new(opts)

  def call(conn, _opts) do
    case List.keyfind(conn.req_headers, "authorization", 0) do
      {_, authorization} -> authorize_session(conn, authorization)
      nil -> deauthorize_session(conn)
    end
  end

  defp authorize_session(conn, authorization), do: put_session(conn, :authorization, authorization)
  defp deauthorize_session(conn), do: delete_session(conn, :authorization)
end
