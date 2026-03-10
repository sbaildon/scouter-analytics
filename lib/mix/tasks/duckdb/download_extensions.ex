defmodule Mix.Tasks.Duckdb.DownloadExtensions do
  @shortdoc "Downloads an ADBC driver"

  @moduledoc false
  use Mix.Task

  require Logger

  def run([]) do
    Mix.shell().error("Usage: mix duckdb.download_extensions extension...")
  end

  def run(extensions) do
    driver = System.get_env("DUCKDB_DRIVER") || :duckdb

    {:ok, database} = Adbc.Database.start_link(driver: driver, entrypoint: "duckdb_adbc_init", path: ":memory:")
    {:ok, conn} = Adbc.Connection.start_link(database: database)

    extension_directory = Ecto.Adapters.DuckDB.resolve_extension_directory()

    {:ok, config_query} = Adbc.Connection.prepare(conn, "SET extension_directory = ?")
    {:ok, _} = Adbc.Connection.query(conn, config_query, [extension_directory])

    for extension <- extensions do
      Mix.shell().info("Downloading #{extension}")
      {:ok, _} = Adbc.Connection.query(conn, "INSTALL #{extension};")
    end
  end
end
