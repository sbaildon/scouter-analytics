defmodule Stats.EventsRepo do
  use Ecto.Repo,
    otp_app: :stats,
    adapter: Ecto.Adapters.DuckDB

  alias Ecto.Query.Planner

  require Logger

  def arrow_query(query, opts \\ []) do
    repo = get_dynamic_repo()

    {adapter_meta, opts} = tuplet = Ecto.Repo.Supervisor.tuplet(repo, prepare_opts(:all, opts))

    %{adapter: adapter, cache: cache} = adapter_meta

    {query, opts} = prepare_query(:all, query, opts)
    query = Planner.attach_prefix(query, opts)

    {query_meta, prepared, cast_params, dump_params} =
      Planner.query(query, :all, cache, adapter, 0)

    {_num, columns} = adapter.execute(adapter_meta, query_meta, prepared, dump_params, opts)

    columns
  end

  def arrow_stream(queryable, opts \\ []) do
    repo = get_dynamic_repo()
    {adapter_meta, opts} = tuplet = Ecto.Repo.Supervisor.tuplet(repo, prepare_opts(:stream, opts))

    %{adapter: adapter, cache: cache} = adapter_meta

    {query, opts} = prepare_query(:stream, queryable, opts)
    query = Planner.attach_prefix(query, opts)

    {query_meta, prepared, cast_params, dump_params} =
      Planner.query(query, :all, cache, adapter, 0)

    adapter.arrow_stream(adapter_meta, query_meta, prepared, dump_params, opts)

  def merge_columns(chunked_results) do
    Stream.zip_with(chunked_results, fn columns ->
      Enum.reduce(columns, fn column, merged_column ->
        %{merged_column | data: merged_column.data ++ column.data}
      end)
    end)
  end
end
