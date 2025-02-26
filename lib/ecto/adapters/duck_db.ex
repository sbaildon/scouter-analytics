defmodule Ecto.Adapters.DuckDB do
  @moduledoc false
  use Ecto.Adapters.SQL,
    driver: :adbc

  alias Ecto.Adapter.Migration

  def arrow_stream(adapter_meta, query_meta, prepared, params, opts) do
    do_stream(adapter_meta, prepared, params, put_source(opts, query_meta))
  end

  defp do_stream(adapter_meta, {:cache, _, {_, prepared}}, params, opts) do
    prepare_stream(adapter_meta, prepared, params, opts)
  end

  defp do_stream(adapter_meta, {:cached, _, _, {_, cached}}, params, opts) do
    prepare_stream(adapter_meta, String.Chars.to_string(cached), params, opts)
  end

  defp do_stream(adapter_meta, {:nocache, {_id, prepared}}, params, opts) do
    prepare_stream(adapter_meta, prepared, params, opts)
  end

  defp prepare_stream(adapter_meta, prepared, params, opts) do
    adapter_meta
    |> Ecto.Adapters.SQL.Stream.build(prepared, params, opts)
    |> reject_end_of_series()
  end

  # exists solely because handle_fetch of DuckDB.Protocol will return :end_of_series
  #
  # i think the expectation is to return {:halt, [], state} but that's confusing to handle
  # given my current worldview of this Adapter/DBConnection malarky
  defp reject_end_of_series(stream) do
    Stream.reject(stream, fn
      :end_of_series -> true
      _ -> false
    end)
  end

  defp put_source(opts, %{sources: sources}) when is_binary(elem(elem(sources, 0), 0)) do
    {source, _, _} = elem(sources, 0)
    [source: source] ++ opts
  end

  defp put_source(opts, _) do
    opts
  end

  @impl Migration
  def supports_ddl_transaction?, do: true

  @impl Migration
  def lock_for_migrations(_meta, _options, fun) do
    fun.()
  end
end
