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
    opts =
      opts
      |> Keyword.put_new(:public, false)
      |> Keyword.put_new(:published, true)

    Multi.new()
    |> Multi.insert(:service, Service.changeset(%{name: namespace, published: opts[:published], public: opts[:public]}))
    |> Multi.insert(:service_provider, fn %{service: service} ->
      Services.Provider.changeset(%{service_id: service.id, namespace: namespace})
    end)
    |> Repo.transaction()
    |> EctoHelpers.take_from_multi(:service)
  end

  def get_by_name(name, opts \\ []) do
    Service.query()
    |> Service.where_published()
    |> Service.where_name(name)
    |> service_query_opts(opts)
    |> Repo.fetch(opts)
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
      _, query -> query
    end)
  end

  defp service_cache, do: ServiceCache

  def clear_cache do
    Cachex.clear(service_cache())
  end
end
