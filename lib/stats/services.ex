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
    |> Repo.insert()
  end

  def register(namespace, opts) do
    opts = Keyword.put_new(opts, :published, true)

    Multi.new()
    |> Multi.insert(:service, Service.changeset(%{name: namespace, published: opts[:published]}))
    |> Multi.insert(:service_provider, fn %{service: service} ->
      Services.Provider.changeset(%{service_id: service.id, namespace: namespace})
    end)
    |> Repo.transaction()
    |> EctoHelpers.take_from_multi(:service)
  end

  def change(service_id, params) do
    Multi.new()
    |> Multi.one(:service, fn _ ->
      service_id
      |> Service.where_id()
      |> Service.with_providers()
      |> EctoHelpers.preload()
    end)
    |> Multi.run(:change, fn _repo, %{service: service} ->
      {:ok, Service.changeset(service, params)}
    end)
    |> Multi.update(:update, & &1.change)
    |> Multi.merge(&update_service_provider_if_name_changed/1)
    |> Repo.transaction()
    |> EctoHelpers.take_from_multi(:update)
  end

  defp update_service_provider_if_name_changed(%{change: change, service: service}) do
    if change.changes[:name] && length(service.providers) == 1 do
      Multi.update(Multi.new(), :service_provider, fn _ ->
        [provider | []] = service.providers
        Services.Provider.changeset(provider, %{namespace: change.changes[:name]})
      end)
    else
      Multi.new()
    end
  end

  def get_by_name(name, opts \\ []) do
    Service.query()
    |> Service.where_published()
    |> Service.where_name(name)
    |> service_query_opts(opts)
    |> Repo.fetch([{:skip_service_id, true} | opts])
  end

  def list(opts \\ []) do
    Service.query()
    |> Service.with_providers()
    |> service_query_opts(opts)
    |> EctoHelpers.preload()
    |> Repo.list()
  end

  def list_published(opts \\ []) do
    Service.query()
    |> Service.where_published()
    |> Service.with_providers()
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
