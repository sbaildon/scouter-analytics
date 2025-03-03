defmodule Ecto.Adapters.DuckDB.Connection do
  @moduledoc false

  alias Ecto.Adapters.DuckDB.Query
  alias Ecto.Adapters.Postgres.Connection, as: Postgres
  alias Ecto.Adapters.SQLite3.Connection, as: SQLite3

  require Logger

  defp default_opts(opts) do
    Keyword.put_new(opts, :database, ":memory:")
  end

  def start_link(opts) do
    opts = default_opts(opts)
    DBConnection.start_link(Ecto.Adapters.DuckDB.Protocol, opts)
  end

  def child_spec(options) do
    {:ok, _} = Application.ensure_all_started(:db_connection)
    options = default_opts(options)
    DBConnection.child_spec(Ecto.Adapters.DuckDB.Protocol, options)
  end

  def stream(conn, statement, params, opts) do
    query = %Query{name: "", statement: statement}
    DBConnection.prepare_stream(conn, query, params, opts)
  end

  def query(conn, sql, params, options) do
    name = Keyword.get(options, :cache_statement)
    statement = IO.iodata_to_binary(sql)
    query = %Query{name: name, statement: statement}

    case DBConnection.prepare_execute(conn, query, params, options) do
      {:ok, _query, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  def prepare_execute(conn, name, statement, params, opts) do
    query = %Query{name: name, statement: statement}
    DBConnection.prepare_execute(conn, query, params, opts)
  end

  def execute(conn, %Query{} = query, params, opts) do
    DBConnection.prepare_execute(conn, query, params, opts)
  end

  def execute(conn, sql, params, opts) do
    query = %Query{name: "", statement: IO.iodata_to_binary(sql)}
    DBConnection.prepare_execute(conn, query, params, opts)
  end

  defdelegate insert(prefix, table, header, rows, on_conflict, returning, placeholders), to: Postgres

  defdelegate all(query), to: SQLite3
  defdelegate all(query, as_prefix), to: SQLite3

  defdelegate update_all(query), to: SQLite3
  defdelegate update_all(query, prefix), to: SQLite3
  defdelegate delete_all(query), to: SQLite3
  defdelegate delete(prefix, table, filters, returning), to: SQLite3
  defdelegate update(prefix, table, fields, filters, returning), to: SQLite3

  def ddl_logs(_), do: []
  defdelegate execute_ddl(command), to: Postgres
end
