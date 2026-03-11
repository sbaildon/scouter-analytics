defmodule Ecto.Adapters.DuckDB do
  @moduledoc false

  @behaviour Ecto.Adapter.Storage

  use Ecto.Adapters.SQL,
    driver: :adbc

  alias Ecto.Adapter.Migration
  alias Ecto.Adapter.Storage

  @impl Migration
  def supports_ddl_transaction?, do: true

  @impl Migration
  def lock_for_migrations(_meta, _options, fun) do
    fun.()
  end

  @impl Storage
  def storage_up(opts) do
    {database, _opts} = Keyword.pop!(opts, :database)

    {:ok, state} = Ecto.Adapters.DuckDB.Protocol.connect(database: database)
    Ecto.Adapters.DuckDB.Protocol.disconnect(nil, state)
  end

  @impl Storage
  def storage_status(opts) do
    {database, _opts} = Keyword.pop!(opts, :database)

    if File.exists?(database) do
      :up
    else
      :down
    end
  end

  @impl Storage
  def storage_down(opts) do
    {database, _opts} = Keyword.pop!(opts, :database)

    File.rm(database)
  end

  def resolve_extension_directory do
    case System.get_env("DUCKDB_DIRECTORY_EXTENSIONS", "priv/duckdb/extensions") do
      "/" <> _ = absolute_path -> absolute_path
      path -> Application.app_dir(:scouter, path)
    end
  end
end
