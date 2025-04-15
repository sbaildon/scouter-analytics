defmodule Scouter.EventsRepo.BackupWorker do
  @moduledoc false
  use Oban.Worker,
    unique: [
      period: :infinity,
      states: duplicate_if_state_is_any()
    ],
    queue: :backups

  alias Scouter.EventsRepo

  def perform(_args) do
    httpfs_credentials =
      :scouter
      |> Application.fetch_env!(Scouter.EventsRepo)
      |> Keyword.fetch!(:httpfs_credentials)

    bucket = System.fetch_env!("BACKUP_BUCKET")
    prefix = System.get_env("BACKUP_PREFIX", "/")

    root = Path.join(["s3://", bucket, prefix])

    EventsRepo.transaction(fn repo ->
      Enum.each(httpfs_credentials, fn {name, credentials} ->
        credentials_query = create_credentials_if_not_exists_query(name, credentials)
        repo.query(credentials_query)
      end)

      repo.query(migration_backup_query(root))

      events_table_name = "events"
      repo.query(events_backup_query(root, events_table_name), [events_table_name])
    end)
  end

  def migration_backup_query(root) do
    to = Path.join([root, "schema_migrations.parquet"])

    """
    COPY schema_migrations TO '#{to}'
    """
  end

  def events_backup_query(root, table_name) do
    to = Path.join([root, table_name <> ".parquet.d"])

    """
    COPY (
    SELECT
      *,
      YEAR(timestamp) AS 'year',
      MONTH(timestamp) AS 'month'
    FROM
      query_table($1)
    ) TO '#{to}' (
    FORMAT parquet,
    OVERWRITE_OR_IGNORE true,
    PARTITION_BY ('service_id', 'year', 'month')
    );
    """
  end

  defp create_credentials_if_not_exists_query(name, opts) do
    "CREATE TEMPORARY SECRET IF NOT EXISTS #{name} (" <> secret_options(opts) <> ");"
  end

  defp secret_options(options) do
    secret_options(options, [])
  end

  defp secret_options([], options) do
    Enum.join(options, ", ")
  end

  defp secret_options([{key, value} | rest], options) do
    secret_options(rest, ["#{key} '#{value}'" | options])
  end

  defp duplicate_if_state_is_any, do: [:retryable, :executing, :available, :scheduled]
end
