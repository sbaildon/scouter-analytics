defmodule Scouter.EventsRepo.BackupWorker do
  @moduledoc false
  use Oban.Worker,
    unique: [
      period: :infinity,
      states: duplicate_if_state_is_any()
    ],
    queue: :backups

  import Ecto.Changeset

  alias Scouter.EventsRepo

  defp bucket(name), do: System.fetch_env!("BACKUP_#{name}_BUCKET")
  defp prefix(name), do: System.get_env("BACKUP_#{name}_PREFIX", "/")

  def perform(%{args: %{"name" => name}}) do
    root = Path.join(["s3://", bucket(name), prefix(name)])

    EventsRepo.transaction(fn repo ->
      credentials_query = create_credentials_if_not_exists_query(name)
      repo.query!(credentials_query, [], log: false)

      repo.query!(migration_backup_query(root), [], log: false)

      events_table_name = "events"
      repo.query!(events_backup_query(root, events_table_name), [events_table_name], log: false)
      repo.query!(delete_credentials_query(name), [], log: false)
    end)
  end

  defp delete_credentials_query(name) do
    "DROP TEMPORARY SECRET #{name};"
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

  defp filter_backup_envs(envs) do
    Enum.filter(envs, fn {k, _v} -> String.starts_with?(k, "BACKUP_") end)
  end

  defp remove_prefix_and_group_by_name(envs) do
    Enum.reduce(envs, %{}, fn {k, v}, acc ->
      %{"name" => name, "parameter" => parameter} =
        Regex.named_captures(~r/^(?<prefix>BACKUP)_(?<name>[A-Za-z0-9]+)_(?<parameter>.+)$/, k)

      Map.update(acc, name, %{parameter => v}, fn existing -> Map.put(existing, parameter, v) end)
    end)
  end

  def config do
    System.get_env()
    |> filter_backup_envs()
    |> remove_prefix_and_group_by_name()
  end

  def read_options!(name) do
    Map.fetch!(config(), name)
  end

  defp create_credentials_if_not_exists_query(name) do
    "CREATE TEMPORARY SECRET IF NOT EXISTS #{name} (" <> secret_options(name) <> ");"
  end

  defp secret_options(name) do
    name
    |> read_options!()
    |> validate_duckdb_secret_parameters()
    |> Enum.to_list()
    |> secret_options([])
  end

  defp secret_options([], options) do
    Enum.join(options, ", ")
  end

  defp secret_options([{key, value} | rest], options) do
    secret_options(rest, ["#{key} '#{value}'" | options])
  end

  defp duplicate_if_state_is_any, do: [:retryable, :executing, :available, :scheduled]

  defp validate_duckdb_secret_parameters(params) do
    types = %{URL_STYLE: :string, ENDPOINT: :string, TYPE: :string, KEY_ID: :string, SECRET: :string, REGION: :string}

    {%{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required(Map.keys(types))
    |> apply_action!(:validate)
  end
end
