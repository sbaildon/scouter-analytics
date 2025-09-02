defmodule Admin.APIController do
  use Admin, :controller

  import Ecto.Changeset

  alias Scouter.Services

  def service(conn, params) do
    with {:ok, %{service: namespace}} <- service_params(params),
         {:ok, service} <- Services.register(namespace, []) do
      text(conn, service.id)
    else
      _ ->
        conn |> put_status(500) |> text("internal server error")
    end
  end

  defp service_params(params) do
    types = %{service: :string}

    {%{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required([:service])
    |> validate_change(:service, &validate_host/2)
    |> apply_action(:validate)
  end

  defp validate_host(key, possible_host) do
    case URI.new("https://#{possible_host}") do
      {:ok, %{host: nil}} -> [{key, "Invalid website address"}]
      {:ok, _} -> []
      {:error, _} -> [{key, "Invalid website address"}]
    end
  end
end
