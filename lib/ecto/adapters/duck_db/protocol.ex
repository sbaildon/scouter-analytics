defmodule Ecto.Adapters.DuckDB.Protocol do
  @moduledoc false
  use DBConnection

  require Logger

  defstruct [:conn, :db, transaction_status: :idle]
  @compile {:inline, db: 0, conn: 0}
  defp db, do: __MODULE__.DB
  defp conn, do: __MODULE__.Conn

  @dynamic_supervisor Ecto.Adapters.DuckDB.Adbc

  @impl DBConnection
  def connect(_opts) do
    {:ok, db} =
      DynamicSupervisor.start_child(
        @dynamic_supervisor,
      )

    {:ok, conn} =
      DynamicSupervisor.start_child(
        @dynamic_supervisor,
        {Adbc.Connection, database: db(), process_options: [name: conn()]}
      )

    state = %__MODULE__{
      db: db,
      conn: conn
    }

    {:ok, state}
  end

  @impl DBConnection
  def disconnect(_err, state) do
    %{db: db, conn: conn} = state
    :ok = DynamicSupervisor.terminate_child(@dynamic_supervisor, conn)
    :ok = DynamicSupervisor.terminate_child(@dynamic_supervisor, db)
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
  def handle_status(_opts, _state) do
    raise "handle_status/2 not impl"
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
    {:ok, ref} = Adbc.Connection.prepare(state.conn, query.statement)

    {:ok, %{query | ref: ref}, state}
  end

  @impl DBConnection
  def checkout(state) do
    {:ok, state}
  end

  @impl DBConnection
  def handle_execute(query, params, _opts, state) do
    case Adbc.Connection.query(state.conn, query.ref, params) do
      {:ok, result} ->
        {:ok, query, result, state}

      _ ->
        raise "query failed"
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
