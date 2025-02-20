defmodule Ecto.Adapters.DuckDB.Connection do
  @moduledoc false
  use Supervisor

  alias Ecto.Adapters.SQLite3.Connection, as: SQLite3

  @compile {:inline, db: 0, conn: 0}
  defp db, do: Stats.RepoTwo
  defp conn, do: Stats.RepoTwoConn

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Adbc.Database, driver: :duckdb, process_options: [name: db()]},
      {Adbc.Connection, database: db(), process_options: [name: conn()]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defdelegate all(command), to: SQLite3
  defdelegate execute_ddl(command), to: SQLite3

  def query(conn, sql, _params, _options) do
    IO.inspect(conn, label: "conn")
    %Exqlite.Query{statement: statement} = Exqlite.Query.build(statement: IO.iodata_to_binary(sql))
    Adbc.Connection.query(conn(), statement, [])
  end

  def run(query) do
    {:ok, query_ref} = Adbc.Connection.prepare(conn(), query)
    {:ok, %Adbc.Result{num_rows: num, data: entries}} = Adbc.Connection.query(conn(), query_ref, [])

    {num, entries}
  end

  def ddl_logs(_), do: []
end
