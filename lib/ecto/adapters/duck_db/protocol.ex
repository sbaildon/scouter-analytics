defmodule Ecto.Adapters.DuckDB.Protocol do
  @moduledoc false
  use DBConnection

  require Explorer.DataFrame, as: DF
  require Explorer.Series, as: S
  require Logger

  defstruct [:conn, transaction_status: :idle]

  @impl DBConnection
  def connect(opts) do
    with {instance, _opts} <- Keyword.pop!(opts, :instance),
         db = lookup({:via, Registry, {Scouter.InstanceRegistry, {instance, :adbc_db}}}),
         {:ok, conn} <- Adbc.Connection.start_link(database: db),
         {:ok, directory} <- resolve_directory(Scouter.Instance.lakehouse_data_path(instance)),
         :ok <- mkdir_p(directory),
         {:ok, _} <- install_extension(conn, System.get_env("DUCKDB_HTTPFS_EXTENSION", "httpfs")),
         {:ok, _} <- install_extension(conn, System.get_env("DUCKDB_DUCKLAKE_EXTENSION", "ducklake")),
         {:ok, _} <- install_extension(conn, System.get_env("DUCKDB_SQLITE_EXTENSION", "sqlite")),
         {:ok, _} <-
           Adbc.Connection.query(
             conn,
             "ATTACH IF NOT EXISTS 'ducklake:sqlite:#{Scouter.Instance.datalake_catalog_path(instance)}' AS ducklake (DATA_PATH '#{Scouter.Instance.lakehouse_data_path(instance)}', ENCRYPTED);"
           ),
         {:ok, _} <- Adbc.Connection.query(conn, "USE ducklake;"),
         {:ok, _} <- Adbc.Connection.query(conn, "CALL ducklake.set_option('parquet_compression', 'zstd');"),
         {:ok, _} <- Adbc.Connection.query(conn, "CALL ducklake.set_option('hive_file_pattern', true);"),
         {:ok, _} <- Adbc.Connection.query(conn, "PRAGMA enable_checkpoint_on_shutdown;") do
      state = %__MODULE__{
        conn: conn
      }

      {:ok, state}
    end
  end

  defp resolve_directory(path), do: {:ok, Path.dirname(path)}

  defp install_extension(conn, extension) do
    Logger.info("installing #{extension}")
    Adbc.Connection.query(conn, "INSTALL '#{extension}';")
  end

  @impl DBConnection
  def disconnect(_err, state) do
    %{conn: conn} = state
    :ok = GenServer.stop(conn)
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

  defp error_to_exception(%ArgumentError{} = error) do
    error
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

  defp lookup({:via, mod, {registry, key}}) do
    [{pid, _}] = apply(mod, :lookup, [registry, key])
    pid
  end
end
