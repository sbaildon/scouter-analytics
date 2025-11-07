defmodule Scouter.Instances.EventsMigrator do
  @moduledoc false
  use GenServer

  alias Ecto.Adapters.SQL

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    with {{registry, key}, opts} <- Keyword.pop(opts, :process),
         [{repo, _}] <- Registry.lookup(registry, key) do
      {:ok, _} =
        SQL.query(
          repo,
          "CREATE TABLE IF NOT EXISTS schema_migrations (version UINT64 not null primary key, inserted_at text not null);"
        )

      migration_source =
        migrations =
        Scouter.EventsRepo
        |> migrations_path()
        |> List.wrap()
        |> migrations_for()
        |> Enum.map(&load_migration!/1)

      for {version, module} <- migrations do
        Ecto.Migrator.up(Scouter.EventsRepo, version, module, [
          {:dynamic_repo, repo} | opts
        ])
      end

      :ignore
    end
  end

  def migrations_path(repo, directory \\ "migrations") do
    config = repo.config()
    priv = config[:priv] || "priv/#{repo |> Module.split() |> List.last() |> Macro.underscore()}"
    app = Keyword.fetch!(config, :otp_app)
    Application.app_dir(app, Path.join(priv, directory))
  end

  def migrations_for(migration_source) when is_list(migration_source) do
    migration_source
    |> Enum.flat_map(fn
      directory when is_binary(directory) ->
        [directory, "**", "*.{ex,exs}"]
        |> Path.join()
        |> Path.wildcard()
        |> Enum.map(&extract_migration_info/1)
        |> Enum.filter(& &1)

      {version, module} ->
        [{version, module, module}]
    end)
    |> Enum.sort()
  end

  defp extract_migration_info(file) do
    base = Path.basename(file)

    case Integer.parse(Path.rootname(base)) do
      {integer, "_" <> name} ->
        if Path.extname(base) == ".ex" do
          # See: https://github.com/elixir-ecto/ecto_sql/issues/599
          IO.warn("""
          file looks like a migration but ends in .ex. \
          Migration files should end in .exs. Use "mix ecto.gen.migration" to generate \
          migration files with the correct extension.\
          """)

          nil
        else
          {integer, name, file}
        end

      _ ->
        nil
    end
  end

  defp load_migration!({version, _, file}) when is_binary(file) do
    loaded_modules = file |> Code.compile_file() |> Enum.map(&elem(&1, 0))

    if mod = Enum.find(loaded_modules, &migration?/1) do
      {version, mod}
    else
      raise Ecto.MigrationError,
            "file #{Path.relative_to_cwd(file)} does not define an Ecto.Migration"
    end
  end

  defp migration?(mod) do
    Code.ensure_loaded?(mod) and function_exported?(mod, :__migration__, 0)
  end
end
