defmodule Stats.Repo do
  use Ecto.Repo,
    otp_app: :stats,
    adapter: Ecto.Adapters.SQLite3

  use EctoHelpers

  require Ecto.Query

  @impl Ecto.Repo
  def prepare_query(_operation, query, opts) do
    ensure_explicit_service_query? = ensure_explicit_service_query?(query.from.source)

    cond do
      opts[:skip_service_id] ->
        {query, opts}

      ensure_explicit_service_query? && filtering_by_service_id?(query) ->
        {query, opts}

      ensure_explicit_service_query? ->
        raise "need an explicit list of services"

      true ->
        {query, opts}
    end
  end

  defp ensure_explicit_service_query?({"services", Stats.Service}) do
    config()[:service_queries_require_service_ids] || false
  end

  defp ensure_explicit_service_query?(_) do
    false
  end

  defp filtering_by_service_id?(query) do
    service_alias = Map.get(query.aliases, :service, false)

    service_alias &&
      Enum.any?(query.wheres, fn wheres ->
        Enum.any?(wheres.params, fn
          {_arg, {:in, {^service_alias, :id}}} -> true
          {_arg, {^service_alias, :id}} -> true
          _ -> false
        end)
      end)
  end
end
