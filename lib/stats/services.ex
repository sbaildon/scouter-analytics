defmodule Stats.Services do
  @moduledoc false
  alias Stats.Repo
  alias Stats.Service
  alias Ecto.Multi

  def add_provider(service_id, namespace) do
    %Services.Provider{service_id: TypeID.from_string!(service_id)}
    |> Services.Provider.changeset(%{
      namespace: namespace
    })
    |> Repo.insert()
  end

  def register(namespace) do
    Multi.new()
    |> Multi.insert(:service, Service.changeset(%{name: namespace}))
    |> Multi.insert(:service_provider, Service.Provider.changeset(%{namespace: namespace}))
    |> Repo.transaction()
    |> EctoHelpers.take_from_multi(:service)
  end

  def get_by_name(name) do
    Service.query()
    |> Service.where_published()
    |> Service.where_name(name)
    |> EctoHelpers.one()
  end

  def list do
    Repo.all(Service)
  end

  def list_published do
    Service.query()
    |> Service.where_published()
    |> Service.with_providers()
    |> EctoHelpers.preload()
    |> Repo.all()
  end
end
