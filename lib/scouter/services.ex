defmodule Scouter.Services do
  @moduledoc false
  use Supervisor

  alias Scouter.Repo
  alias Scouter.Service
  alias Scouter.Services
  alias Scouter.Services.Matcher

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

  def fetch(instance, service_id, opts \\ []) do
    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          Service.query()
          |> Service.where_id(service_id)
          |> Service.with_matchers()
          |> EctoHelpers.preload()
          |> repo.fetch(opts)
          |> then(fn
            {:ok, service} -> {:ok, calculate_matchers(service)}
            :error -> {:error, :not_found}
            other -> other
          end)
        end,
        opts
      )
    end)
  end

  defp calculate_matchers(%{matchers: matchers} = service) do
    %{service | matchers: for(matcher <- matchers, do: calculate_matcher(matcher))}
  end

  defp calculate_matcher(%{type: :regex, value: pattern} = matcher) do
    with {:ok, regex} <- Regex.compile(pattern) do
      %{matcher | regex: regex}
    end
  end

  defp calculate_matcher(%{type: :wildcard, value: wildcard} = matcher) do
    with {:ok, regex} <- wildcard |> wildcard_to_regex() |> Regex.compile() do
      %{matcher | regex: regex}
    end
  end

  defp wildcard_to_regex(value) do
    value
    |> String.graphemes()
    |> Enum.map_join(fn
      "*" -> "(?!-)[A-Za-z0-9-]{1,63}(?<!-)"
      other -> other
    end)
    |> then(fn pattern ->
      [?^, pattern, ?$]
    end)
    |> IO.iodata_to_binary()
  end

  def delete(instance, service_id, opts \\ []) do
    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          {_, _matchers} = repo.delete_all(Services.Matcher.where_service(service_id))
          {:ok, service} = repo.fetch(Service.where_id(service_id))
          {:ok, _} = repo.delete(service)
          {:ok, service}
        end,
        [{:mode, :immediate} | opts]
      )
    end)
  end

  def register(instance, params, opts \\ []) do
    params = Map.put_new(params, :published, true)

    Scouter.with_instance(instance, fn %{state_dir: _state_dir} ->
      Repo.transact(
        fn repo ->
          repo.insert(Service.changeset(params))
        end,
        [{:mode, :immediate} | opts]
      )
    end)
  end

  def add_matcher(instance, service_id, type, value) do
    Scouter.with_instance(instance, fn _ ->
      Repo.insert(%Scouter.Services.Matcher{service_id: service_id, type: type, value: value})
    end)
  end

  def change(instance, service_id, params, opts \\ []) do
    read_query =
      service_id
      |> Service.where_id()
      |> Service.with_matchers()
      |> EctoHelpers.preload()

    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          {:ok, service} = repo.fetch(read_query)

          {:ok, _service} = repo.update(Service.changeset(service, params))

          repo.fetch(read_query)
        end,
        [{:mode, :immediate} | opts]
      )
    end)
  end

  def fetch_by_name(instance, name, opts \\ []) do
    Scouter.with_instance(instance, fn _ ->
      fn repo ->
        Service.query()
        |> Service.where_published()
        |> Service.with_matchers()
        |> Service.where_name(name)
        |> service_query_opts(opts)
        |> EctoHelpers.preload()
        |> repo.fetch([{:skip_service_id, true} | opts])
        |> case do
          {:ok, service} -> {:ok, service}
          :error -> {:error, nil}
        end
      end
      |> Repo.transact(opts)
      |> case do
        {:ok, service} -> {:ok, service}
        {:error, nil} -> :error
      end
    end)
  end

  def list(instance, opts \\ []) do
    Scouter.with_instance(instance, fn _ ->
      Repo.transact(
        fn repo ->
          Service.query()
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
