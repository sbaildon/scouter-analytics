defmodule Scouter.Instance do
  @moduledoc false
  use Supervisor

  alias Scouter.InstanceRegistry
  alias Scouter.Instances.Migrator

  require Logger

  defstruct [
    :name,
    :repo,
    :events_repo
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          repo: pid(),
          events_repo: pid()
        }

  # opts is [local: path], [fd: fd], or [port: port]
  def start_link(opts) do
    {:ok, name} = Keyword.fetch(opts, :name)

    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(opts) do
    name =
      _instance_name =
      case opts[:name] do
        {:via, Registry, {InstanceRegistry, instance_name}} -> instance_name
        _instance_name -> raise ArgumentError, "only via tuples are supported"
      end

    children = [
      {ConCache, name: {:via, Registry, {InstanceRegistry, {name, :cache}}}, ttl_check_interval: false},
      {Scouter.Repo, repo_config(name)},
      Supervisor.child_spec(
        {Migrator,
         skip: skip_migrations?(), repos: [Scouter.Repo], process: {:via, Registry, {InstanceRegistry, {name, :repo}}}},
        id: :repo_migrator
      ),
      {Oban,
       oban_config(:scouter) ++
         [
           name: {:via, Registry, {InstanceRegistry, {name, :oban}}},
           get_dynamic_repo: fn ->
             [{pid, _}] = Registry.lookup(InstanceRegistry, {name, :repo})
             pid
           end
         ]},
      {Adbc.Database,
       [
         driver: :duckdb,
         path: ":memory:",
         process_options: [name: {:via, Registry, {InstanceRegistry, {name, :adbc_db}}}]
       ]},
      {Scouter.EventsRepo, events_repo_config(name)},
      Supervisor.child_spec(
        {Scouter.Instances.EventsMigrator,
         instance: name,
         pool_size: 1,
         skip_table_creation: true,
         skip: skip_migrations?(),
         repos: [Scouter.EventsRepo],
         process: {:via, Registry, {InstanceRegistry, {name, :events_repo}}}},
        id: :events_repo_migrator
      ),
      bandit([{:instance, name} | opts])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp repo_config(:main = name) do
    Keyword.put(Scouter.Repo.config(), :name, {:via, Registry, {InstanceRegistry, {name, :repo}}})
  end

  defp repo_config(name) do
    Scouter.Repo.config()
    |> Keyword.put(:name, {:via, Registry, {InstanceRegistry, {name, :repo}}})
    |> Keyword.replace(:database, database_path(name))
  end

  defp events_repo_config(:main = name) do
    Scouter.EventsRepo.config()
    |> Keyword.put(:name, {:via, Registry, {InstanceRegistry, {name, :events_repo}}})
    |> Keyword.put(:instance, name)
  end

  defp events_repo_config(name) do
    Scouter.EventsRepo.config()
    |> Keyword.put(:name, {:via, Registry, {InstanceRegistry, {name, :events_repo}}})
    |> Keyword.put(:instance, name)
  end

  def build(name) do
    with {:ok, registered_pids} <- registered_pids(name) do
      {:ok, struct(__MODULE__, Enum.reduce([registered_pids, %{name: name}], %{}, &Map.merge/2))}
    end
  end

  def registered_pids(name) do
    {:ok,
     %{
       repo: lookup_pid!(InstanceRegistry, {name, :repo}),
       events_repo: lookup_pid!(InstanceRegistry, {name, :events_repo})
     }}
  end

  defp lookup_pid!(registry, key) do
    with [{pid, _}] <- Registry.lookup(registry, key), do: pid
  end

  defp bandit(opts) do
    cond do
      socket = opts[:local] ->
        File.rm(socket)
        socket |> Path.dirname() |> File.mkdir_p()
        {Bandit, base_config(opts) ++ af_unix(socket)}

      fd = opts[:fd] ->
        {Bandit, base_config(opts) ++ af_unix(fd)}

      port = opts[:port] ->
        {Bandit, base_config(opts) ++ af_inet6(port)}

      true ->
        raise "need an fd or a port"
    end
  end

  defp base_config(opts) do
    with {:ok, instance} <- Keyword.fetch(opts, :instance) do
      [plug: {Telemetry.Endpoint, [instance: instance]}, scheme: :http]
    end
  end

  defp af_unix(socket) when is_binary(socket) do
    [
      ip: {:local, socket},
      port: 0
    ]
  end

  defp af_unix(fd) when is_integer(fd) do
    [
      thousand_island_options: [
        port: 0,
        transport_options: [
          {:fd, fd},
          :local
        ]
      ]
    ]
  end

  defp af_inet6(port) do
    [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port]
  end

  def state_directory do
    Enum.find_value(
      ["STATE_DIRECTORY", "XDG_DATA_HOME"],
      default_state_directory(),
      &System.get_env/1
    )
  end

  defp default_state_directory, do: "/var/lib/scouter/analytics"

  def database_path(name) when is_atom(name), do: name |> Atom.to_string() |> database_path()

  def database_path(name), do: Path.join([state_directory(), "instances", name, "domain.db"])

  def datalake_catalog_path(name) when is_atom(name), do: name |> Atom.to_string() |> datalake_catalog_path()

  def datalake_catalog_path(name), do: Path.join([state_directory(), "instances", name, "catalog.db"])

  def datalake_storage_path(name) when is_atom(name), do: name |> Atom.to_string() |> datalake_storage_path()
  def datalake_storage_path(name), do: Path.join([state_directory(), "instances", name])

  defp skip_migrations? do
    value = System.get_env("RUN_MIGRATIONS", "false")
    not String.to_existing_atom(value)
  end

  def oban_config(otp_app) do
    Application.fetch_env!(otp_app, Oban)
  end
end
