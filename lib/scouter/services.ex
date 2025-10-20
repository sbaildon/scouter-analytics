defmodule Scouter.Services do
  @moduledoc false
  use Supervisor

  alias Scouter.Repo
  alias Scouter.Service
  alias Scouter.Services

  require Logger

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

  def fetch_by_namespace(instance, namespace, opts \\ [])

  def fetch_by_namespace(_, nil, _opts) do
    :error
  end

  def fetch_by_namespace(instance, namespace, opts) do
    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          Service.query()
          |> Service.with_providers()
          |> Services.Provider.where_ns(namespace, from: :providers)
          |> repo.fetch([{:skip_service_id, true} | opts])
        end,
        opts
      )
    end)
  end

  def fetch(instance, service_id, opts \\ []) do
    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          Service.query()
          |> Service.where_id(service_id)
          |> Service.with_primary_provider()
          |> EctoHelpers.preload()
          |> repo.fetch(opts)
        end,
        opts
      )
    end)
  end

  def delete(instance, service_id, opts \\ []) do
    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          {_, _providers} = repo.delete_all(Services.Provider.where_service(service_id))
          {:ok, service} = repo.fetch(Service.where_id(service_id))
          {:ok, _} = repo.delete(service)

          socket = service_socket(service)

          :ok = File.rm(socket)

          dir = Path.dirname(socket)

          with {:ok, []} <- File.ls(dir) do
            File.rmdir(dir)
          end

          {:ok, service}
        end,
        [{:mode, :immediate} | opts]
      )
    end)
  end

  def get_for_namespace(instance, namespace, opts \\ []) do
    {_, result} =
      Cachex.fetch(service_cache(), {instance, namespace}, fn ->
        Scouter.with_instance(instance, fn _ ->
          Service.query()
          |> Service.with_providers()
          |> Services.Provider.where_ns(namespace, from: :providers)
          |> EctoHelpers.preload()
          |> Repo.fetch([{:skip_service_id, true} | opts])
          |> case do
            {:ok, service} -> {:commit, {:ok, service}, expire: to_timeout(second: 30)}
            :error -> {:ignore, :error}
          end
        end)
      end)

    result
  end

  def register(instance, namespace, data \\ [], opts \\ []) do
    data = Keyword.put_new(data, :published, true)

    Scouter.with_instance(instance, fn %{state_dir: _state_dir} ->
      Repo.transact(
        fn repo ->
          {:ok, service} = repo.insert(Service.changeset(%{published: data[:published]}))

          {:ok, service_provider} =
            repo.insert(Services.Provider.changeset(%{service_id: service.id, namespace: namespace}))

          {:ok, update} = repo.update(Service.set_primary_provider(service, service_provider.id))

          :ok = service.id |> service_socket() |> Path.dirname() |> File.mkdir_p()
          :ok = File.ln_s(instance_socket(instance), service_socket(service))

          {:ok, update}
        end,
        [{:mode, :immediate} | opts]
      )
    end)
  end

  defp service_socket(service) when is_struct(service), do: service_socket(service.id)

  defp service_socket(service_id),
    do: Path.join([System.fetch_env!("RUNTIME_DIRECTORY"), "scouter", "analytics", "services", service_id, "socket"])

  defp instance_socket(instance) when is_atom(instance), do: instance |> to_string() |> instance_socket()

  defp instance_socket(instance),
    do: Path.join([System.fetch_env!("RUNTIME_DIRECTORY"), "scouter", "analytics", "instances", instance, "socket"])

  def change(instance, service_id, params, opts \\ []) do
    read_query =
      service_id
      |> Service.where_id()
      |> Service.with_providers()
      |> Service.with_primary_provider()
      |> EctoHelpers.preload()

    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          {:ok, service} = repo.one(read_query)

          {:ok, _} = repo.update(Service.changeset(service, params))
          {:ok, _} = repo.update(Services.Provider.changeset(service.primary_provider, params))

          repo.one(read_query)
        end,
        [{:mode, :immediate} | opts]
      )
    end)
  end

  def get_by_name(instance, name, opts \\ []) do
    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          Service.query()
          |> Service.where_published()
          |> Service.with_providers()
          |> Service.with_primary_provider()
          |> Services.Provider.where_ns(name, from: :primary_provider)
          |> service_query_opts(opts)
          |> EctoHelpers.preload()
          |> repo.fetch([{:skip_service_id, true} | opts])
        end,
        opts
      )
    end)
  end

  @doc """
  Scouter makes no promises that namespaces are unique across instances. That's your respnsibility.
  This function runs async queries across all instances and the first one wins.
  """
  def get_instance_for_primary_namespace(namespace) do
    query =
      Service.query()
      |> Service.with_providers()
      |> Service.with_primary_provider()
      |> Services.Provider.where_ns(namespace, from: :primary_provider)
      |> EctoHelpers.preload()

    Scouter.list_instances()
    |> Task.async_stream(
      fn instance ->
        Scouter.with_instance(instance, fn _ ->
          case Repo.fetch(query, skip_service_id: true) do
            {:ok, _service} -> instance
            :error -> false
          end
        end)
      end,
      ordered: false
    )
    |> Enum.find(fn {:ok, value} -> value end)
  end

  def list(instance, opts \\ []) do
    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          Service.query()
          |> Service.with_providers()
          |> Service.with_primary_provider()
          |> service_query_opts(opts)
          |> EctoHelpers.preload()
          |> repo.list(opts)
        end,
        opts
      )
    end)
  end

  def list_published(instance, opts \\ []) do
    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          Service.query()
          |> Service.where_published()
          |> Service.with_providers()
          |> Service.with_primary_provider()
          |> service_query_opts(opts)
          |> EctoHelpers.preload()
          |> repo.list(opts)
        end,
        opts
      )
    end)
  end

  defp service_query_opts(query, opts) do
    Enum.reduce(opts, query, fn
      {:ids, []}, query -> query
      {:ids, service_ids}, query -> Service.where_id(query, service_ids)
      {:shared, true}, query -> Service.where_shared(query)
      _, query -> query
    end)
  end

  defp service_cache, do: ServiceCache

  def clear_cache do
    Cachex.clear(service_cache())
  end
end
