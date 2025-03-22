defmodule Stats.Services do
  @moduledoc false
  use Supervisor

  alias Ecto.Multi
  alias Stats.Repo
  alias Stats.Service
  alias Stats.Services

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = [
      {Cachex, name: service_cache()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def get_for_namespace(namespace) do
    Cachex.fetch(service_cache(), namespace, fn namespace ->
      service =
        Service.query()
        |> Service.with_providers(as: :provider)
        |> Services.Provider.where_ns(namespace)
        |> EctoHelpers.preload()
        |> Repo.one()

      if service do
        {:commit, service}
      else
        {:ignore, nil}
      end
    end)
  end

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

  defp service_cache, do: ServiceCache

  def clear_cache do
    Cachex.clear(service_cache())
  end
end
