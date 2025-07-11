defmodule Scouter.Services do
  @moduledoc false
  use Supervisor

  alias Ecto.Multi
  alias Scouter.Repo
  alias Scouter.Service
  alias Scouter.Services
  alias Scouter.Writer, as: WRepo

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

  def fetch(service_id) do
    Service.query()
    |> Service.where_id(service_id)
    |> Service.with_primary_provider()
    |> EctoHelpers.preload()
    |> Repo.fetch()
  end

  def delete(service_id) do
    Multi.new()
    |> Multi.delete_all(:provides, Services.Provider.where_service(service_id))
    |> Multi.one(:service, Service.where_id(service_id))
    |> Multi.delete(:delete, fn %{service: service} -> service end)
    |> WRepo.transaction()
    |> EctoHelpers.take_from_multi(:service)
  end

  def get_for_namespace(namespace) do
    Cachex.fetch(service_cache(), namespace, fn namespace ->
      service =
        Service.query()
        |> Service.with_providers()
        |> Services.Provider.where_ns(namespace, from: :providers)
        |> EctoHelpers.preload()
        |> Repo.one(skip_service_id: true)

      if service do
        {:commit, service}
      else
        {:ignore, nil}
      end
    end)
  end

  def add_provider(service_id, namespace) do
    %{
      service_id: service_id,
      namespace: namespace
    }
    |> Services.Provider.changeset()
    |> WRepo.insert()
  end

  def register(namespace, opts) do
    opts = Keyword.put_new(opts, :published, true)

    Multi.new()
    |> Multi.insert(:service, Service.changeset(%{published: opts[:published]}))
    |> Multi.insert(:service_provider, fn %{service: service} ->
      Services.Provider.changeset(%{service_id: service.id, namespace: namespace})
    end)
    |> Multi.update(:primary_provider, fn %{service: service, service_provider: service_provider} ->
      Service.set_primary_provider(service, service_provider.id)
    end)
    |> WRepo.transaction()
    |> EctoHelpers.take_from_multi(:service)
  end

  def change(service_id, params) do
    read_query =
      service_id
      |> Service.where_id()
      |> Service.with_providers()
      |> Service.with_primary_provider()
      |> EctoHelpers.preload()

    Multi.new()
    |> Multi.one(:service, fn _ ->
      read_query
    end)
    |> Multi.update(:update, fn %{service: service} ->
      Service.changeset(service, params)
    end)
    |> Multi.update(:update_two, fn %{service: service} ->
      Services.Provider.changeset(service.primary_provider, params)
    end)
    |> Multi.one(:read_after_write, fn _ ->
      read_query
    end)
    |> WRepo.transaction()
    |> EctoHelpers.take_from_multi(:read_after_write)
  end

  def get_by_name(name, opts \\ []) do
    Service.query()
    |> Service.where_published()
    |> Service.with_providers()
    |> Service.with_primary_provider()
    |> Services.Provider.where_ns(name, from: :primary_provider)
    |> service_query_opts(opts)
    |> EctoHelpers.preload()
    |> Repo.fetch([{:skip_service_id, true} | opts])
  end

  def list(opts \\ []) do
    Service.query()
    |> Service.with_providers()
    |> Service.with_primary_provider()
    |> service_query_opts(opts)
    |> EctoHelpers.preload()
    |> Repo.list(opts)
  end

  def list_published(opts \\ []) do
    Service.query()
    |> Service.where_published()
    |> Service.with_providers()
    |> Service.with_primary_provider()
    |> service_query_opts(opts)
    |> EctoHelpers.preload()
    |> Repo.list()
  end

  defp service_query_opts(query, opts) do
    Enum.reduce(opts, query, fn
      {:only, []}, query -> query
      {:only, service_ids}, query -> Service.where_id(query, service_ids)
      {:shared, true}, query -> Service.where_shared(query)
      _, query -> query
    end)
  end

  defp service_cache, do: ServiceCache

  def clear_cache do
    Cachex.clear(service_cache())
  end
end
