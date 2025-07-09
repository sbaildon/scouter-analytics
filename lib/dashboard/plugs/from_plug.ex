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
    with {_, from} <- List.keyfind(conn.req_headers, "from", 0),
         {:ok, email} <- parse_email(from) do
      Logger.debug(user: from)
      conn |> put_session(:from, email) |> assign(:from, email)
    else
      _ -> conn
    end
  end

  defp parse_email(potential_email) do
    types = %{email: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(%{"email" => potential_email}, Map.keys(types))
    |> EctoHelpers.validate_email()
    |> Ecto.Changeset.apply_action(:validate)
    |> case do
      {:ok, %{email: email}} -> {:ok, email}
      other -> other
    end
  end
end
