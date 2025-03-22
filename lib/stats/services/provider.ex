defmodule Stats.Services.Provider do
  @moduledoc false
  use Stats.Schema, prefix: "svc_provider"

  import Ecto.Query

  alias Stats.Service

  schema "service_providers" do
    belongs_to :service, Service
    field :namespace, :string
    timestamps()
  end

  def changeset(svc_provider, params) do
    svc_provider
    |> cast(params, [:namespace])
    |> validate_required([:namespace])
  end

  defp named_binding, do: :provider

  def where_ns(query, ns) do
    from([{^named_binding(), struct}] in query,
      where: struct.namespace == ^ns
    )
  end
end
