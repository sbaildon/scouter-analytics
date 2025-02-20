defmodule Ecto.Adapters.DuckDB do
  @moduledoc false
  @behaviour Ecto.Adapter
  @behaviour Ecto.Adapter.Migration
  @behaviour Ecto.Adapter.Queryable
  @behaviour Ecto.Adapter.Transaction

  alias Ecto.Adapter.Migration
  alias Ecto.Adapter.Queryable
  alias Ecto.Adapter.Transaction
  alias Ecto.Adapters.SQL

  require Logger

  @compile {:inline, driver: 0, conn: 0}
  defp conn, do: __MODULE__.Connection
  defp driver, do: :adbc

  @impl true
  def checkout(_adapter_meta, _config, _function) do
    raise "not impl"
  end

  @impl true
  def ensure_all_started(config, type) do
    SQL.ensure_all_started(driver(), config, type)
  end

  @impl Ecto.Adapter
  def init(_config) do
    meta = %{
      opts: [],
      telemetry: {Stats.EventsRepo, :debug, [:stats, :repo, :query]},
      sql: __MODULE__.Connection
    }

    child_spec = Supervisor.child_spec(Ecto.Adapters.DuckDB.Connection, [])
    {:ok, child_spec, meta}
  end

  @impl true
  def checked_out?(_adapter_meta) do
    raise "not impl"
  end

  @impl true
  defmacro __before_compile__(env) do
    SQL.__before_compile__(:adbc, env)
  end

  @impl Queryable
  def prepare(:all, query) do
    {:cache, {System.unique_integer([:positive]), IO.iodata_to_binary(conn().all(query))}}
  end

  @impl true
  def stream(_adapter_meta, _query_meta, _query_cache, _params, _options) do
    raise "not good"
  end

  @impl Queryable
  def execute(_adapter_meta, _query_meta, query_cache, _params, _options) do
    {:cache, _fun, {_number, sql}} = query_cache
    conn().run(sql)
    # {:ok, query_ref} = Adbc.Connection
    #     IO.inspect(query_meta, label: "query_meta")
    #     IO.inspect(query_cache, label: "query_cache")
    #     IO.inspect(options, label: "options")
    #
  end

  @impl Ecto.Adapter
  def loaders(_primitive_type, _ecto_type) do
    raise "not good"
  end

  @impl Ecto.Adapter
  def dumpers(_primitive_type, _ecto_type) do
    raise "not good"
  end

  @impl Migration
  def execute_ddl(adapter_meta, definition, opts) do
    SQL.execute_ddl(adapter_meta, conn(), definition, opts)
  end

  @impl Migration
  def supports_ddl_transaction?, do: true

  @impl Migration
  def lock_for_migrations(_adapter_meta, _options, fun) do
    fun.()
  end

  @impl Transaction
  def in_transaction?(_adapter_meta) do
    raise "in_transaction/1 not impl"
  end

  @impl Transaction
  def transaction(adapter_meta, options, function) do
    SQL.transaction(adapter_meta, options, function)
  end

  @impl Transaction
  def rollback(_adapter_meta, _value) do
    raise "rollback/2 not impl"
  end
end
