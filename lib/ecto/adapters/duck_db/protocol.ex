defmodule Ecto.Adapters.DuckDB.Protocol do
  @moduledoc false
  use DBConnection

  require Explorer.DataFrame, as: DF
  require Explorer.Series, as: S
  require Logger

  defstruct [:conn, :db, transaction_status: :idle]

  @impl DBConnection
  def connect(opts) do
    with {path, _opts} <- Keyword.pop!(opts, :database),
         {:ok, db} <- Adbc.Database.start_link(driver: :duckdb, path: path),
         {:ok, conn} <- Adbc.Connection.start_link(database: db),
         {:ok, _} <- Adbc.Connection.query(conn, "PRAGMA enable_checkpoint_on_shutdown;"),
         {:ok, _} <- run_custom_schema_migrations_table(conn) do
      state = %__MODULE__{
        db: db,
        conn: conn
      }

      {:ok, state}
    end
  end

  # because there's some sort of race condition when pool_size >1, the
  # repo will start claiming there's no schema_migrations table,
  # but after inspecting the db immediately after the crash the table exists.
  # one theory is the table is made but the process running the migrations runs before the
  # create schema_migrations table is commited
  defp run_custom_schema_migrations_table(conn) do
    Adbc.Connection.query(
      conn,
      "CREATE TABLE IF NOT EXISTS schema_migrations (version UINT64 not null primary key, inserted_at text not null);"
    )
  end

  @impl DBConnection
  def disconnect(_err, state) do
    %{db: db, conn: conn} = state
    :ok = GenServer.stop(conn)
    :ok = GenServer.stop(db)
    :ok
  end

  @impl DBConnection
  def handle_begin(_opts, %{transaction_status: :idle} = state) do
    {:ok, result} = Adbc.Connection.query(state.conn, "BEGIN TRANSACTION;")
    {:ok, result, %{state | transaction_status: :transaction}}
  end

  @impl DBConnection
  def handle_begin(_opts, %{transaction_status: status} = state) do
    {status, state}
  end

  @impl DBConnection
  def handle_close(_query, _opts, state) do
    {:ok, nil, state}
  end

  @impl DBConnection
  def handle_commit(_opts, %{transaction_status: :transaction} = state) do
    {:ok, result} = Adbc.Connection.query(state.conn, "COMMIT")
    {:ok, result, %{state | transaction_status: :idle}}
  end

  @impl DBConnection
  def handle_commit(_opts, %{transaction_status: status} = state) do
    {status, state}
  end

  @impl DBConnection
  def handle_status(_opts, %{transaction_status: :transaction} = state) do
    {:transaction, state}
  end

  @impl DBConnection
  def handle_status(_opts, state) do
    {:idle, state}
  end

  @impl DBConnection
  def handle_rollback(_opts, %{transaction_status: :transaction} = state) do
    {:ok, result} = Adbc.Connection.query(state.conn, "ROLLBACK")
    {:ok, result, %{state | transaction_status: :idle}}
  end

  @impl DBConnection
  def handle_rollback(_opts, %{transaction_status: status} = state) do
    {status, state}
  end

  @impl DBConnection
  def handle_prepare(query, _opts, state) do
    case Adbc.Connection.prepare(state.conn, query.statement) do
      {:ok, ref} ->
        {:ok, %{query | ref: ref}, state}

      {:error, %{message: message}} ->
        {:error, message, state}
    end
  end

  @impl DBConnection
  def checkout(state) do
    {:ok, state}
  end

  @impl DBConnection
  def handle_execute(query, params, opts, state) do
    case Keyword.fetch(opts, :df) do
      {:ok, true} ->
        handle_df_query(query, params, opts, state)

      :error ->
        handle_traditional_query(query, params, opts, state)
    end
  end

  defp handle_df_query(query, params, _opts, state) do
    case DF.from_query(state.conn, query.statement, params) do
      {:ok, result} -> {:ok, query, result, state}
      _ -> {:error, :bad}
    end
  end

  defp handle_traditional_query(query, params, _opts, state) do
    case Adbc.Connection.query(state.conn, query.ref, params) do
      {:ok, result} ->
        {:ok, query, result, state}

      {:error, reason} ->
        {:error, error_to_exception(reason), state}
    end
  end

  @impl true
  def handle_declare(query, params, _opts, state) do
    command = {:query, query.statement, params, []}

    case GenServer.call(state.conn, {:stream, command}, :infinity) do
      {:ok, _conn, unlock_ref, stream_ref, _rows_affected} ->
        {:ok, query, {stream_ref, unlock_ref}, state}

      {:error, reason} ->
        {:disconnect, error_to_exception(reason), state}
    end
  end

  @impl DBConnection
  def handle_fetch(_query, {stream_ref, _unlock_ref}, _opts, state) do
    case Adbc.Nif.adbc_arrow_array_stream_next(stream_ref) do
      {:ok, result} ->
        {:cont, Enum.map(result, &Adbc.Column.materialize/1), state}

      :end_of_series ->
        {:halt, :end_of_series, state}

      {:error, reason} ->
        {:error, error_to_exception(reason)}
    end
  end

  @impl DBConnection
  def handle_deallocate(_query, {_stream_ref, unlock_ref}, _opts, state) do
    :ok = GenServer.cast(state.conn, {:unlock, unlock_ref})
    {:ok, nil, state}
  end

  @impl DBConnection
  def ping(state) do
    {:ok, _} = Adbc.Connection.get_info(state.conn)

    {:ok, state}
  end

  defp error_to_exception(string) when is_binary(string) do
    ArgumentError.exception(string)
  end

  defp error_to_exception(list) when is_list(list) do
    ArgumentError.exception(List.to_string(list))
  end

  defp error_to_exception({:adbc_error, message, vendor_code, state}) do
    Adbc.Error.exception(message: message, vendor_code: vendor_code, state: state)
  end

  defp error_to_exception(%Adbc.Error{} = exception) do
    exception
  end
end
