defmodule Scouter.Services.Provider do
  @moduledoc false
  use Schema, prefix: "svc_provider"

  import Ecto.Query

  alias Scouter.Service

  schema "service_providers" do
    belongs_to :service, Service
    field :namespace, :string
    timestamps()
  end

  def changeset(svc_provider, params) do
    svc_provider
    |> cast(params, [:service_id, :namespace])
    |> validate_required([:service_id])
    |> validate_required(:namespace, message: "Namespace required")
    |> unique_constraint(:namespace)
  end

  defp named_binding, do: :provider

  def query do
    from(__MODULE__, as: ^named_binding())
  end

  def where_service(service_id) do
    where_service(query(), service_id)
  end

  def where_service(query, service_id) do
    from([{^named_binding(), struct}] in query,
      where: struct.service_id == ^service_id
    )
  end

  def where_ns(query, ns, opts \\ []) do
    from = Keyword.get(opts, :from, named_binding())

    from([{^from, struct}] in query,
      where: struct.namespace == ^ns
    )
  end
end
