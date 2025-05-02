defmodule Dashboard.FromPlug do
  @moduledoc false
  import Plug.Conn

  require Logger

  def init(opts), do: Map.new(opts)

  def call(conn, _opts) do
    case conn.assigns do
      %{environment: :trusted} ->
        maybe_assign_from(conn)

      _ ->
        conn
    end
  end

  defp maybe_assign_from(conn) do
    case List.keyfind(conn.req_headers, "from", 0) do
      {_, from} ->
        Logger.debug(from: from)
        conn |> put_session(:from, from) |> assign(:from, from)

      nil ->
        conn
    end
  end
end
