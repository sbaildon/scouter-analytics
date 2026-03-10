defmodule Scouter.Events do
  @moduledoc false
  import Scouter.Events.GroupingID

  alias Scouter.Event
  alias Scouter.EventsRepo

  require Explorer.DataFrame, as: DF
  require Explorer.Series, as: S
  require Logger

  @spec arrow(instance :: any(), filters :: keyword()) ::
          %{non_neg_integer() => Explorer.DataFrame.t()} | nil
  def arrow(instance, filters \\ []) do
    Scouter.with_instance(instance, fn %{repo: repo} ->
      result =
        Scouter.PageView.query()
        |> Scouter.PageView.typed_aggregate_query()
        |> filter(filters)
        |> then(&Ecto.Adapters.SQL.to_sql(:all, repo, &1))
        |> then(fn {sql, params} ->
          Scouter.EventsRepo.query(sql, params, df: true)
        end)

      case result do
        {:ok, df} ->
          if DF.n_rows(df) == 0 do
            nil
          else
            df
            |> DF.group_by(:grouping_id)
            |> DF.head(event_limit())
            |> partition_by()
            |> Map.new(&make_presentable/1)
          end

        _ ->
          nil
      end
    end)
  end

  def count(instance) do
    instance
    |> Scouter.with_instance(fn _ ->
      Scouter.EventsRepo.aggregate(Scouter.Event.query(), :count)
    end)
    |> case do
      count when is_integer(count) ->
        {:ok, count}

      result ->
        Logger.info(result)
        :error
    end
  end

  def count(instance, starting, ending) do
    instance
    |> Scouter.with_instance(fn _ ->
      Scouter.Event.query()
      |> Scouter.Event.starting(starting)
      |> Scouter.Event.ending(ending)
      |> Scouter.EventsRepo.aggregate(:count)
    end)
    |> case do
      count when is_integer(count) ->
        {:ok, count}

      result ->
        Logger.info(result)
        :error
    end
  end

  defp make_presentable({grouping_id, df}) when grouping_id in [group_id(:referrer), group_id(:country_code)] do
    series = S.transform(df[:value], fn v -> Scouter.Event.present(grouping_id, v) end)
    {grouping_id, DF.put(df, :present, series)}
  end

  defp make_presentable({grouping_id, df}) do
    {grouping_id, df}
  end

  defp partition_by(%Explorer.DataFrame{} = df) do
    [column | []] = DF.groups(df)

    for value <- df[column] |> S.distinct() |> S.to_list(), into: %{} do
      {value, df |> DF.ungroup() |> DF.filter(col(^column) == ^value) |> DF.discard(column)}
    end
  end

  # maybe take inspiration from the reduce statement here
  # https://hexdocs.pm/ecto/dynamic-queries.html#building-dynamic-queries
  defp filter(query, []), do: query

  defp filter(query, [{_, nil} | rest]) do
    filter(query, rest)
  end

  defp filter(query, [{_, []} | rest]) do
    filter(query, rest)
  end

  defp filter(query, [{:interval, "year_to_date"} | rest]) do
    filter(Event.from_truncated_date(query, "year"), rest)
  end

  defp filter(query, [{:interval, "month_to_date"} | rest]) do
    filter(Event.from_truncated_date(query, "month"), rest)
  end

  defp filter(query, [{:interval, "hour"} | rest]) do
    filter(Event.from_truncated_date(query, "hour"), rest)
  end

  defp filter(query, [{:interval, "today"} | rest]) do
    filter(Event.from_truncated_date(query, "day"), rest)
  end

  defp filter(query, [{:interval, "yesterday"} | rest]) do
    filter(Event.last_calendar(query, "day"), rest)
  end

  defp filter(query, [{:interval, "last_year"} | rest]) do
    filter(Event.last_calendar(query, "year"), rest)
  end

  defp filter(query, [{:interval, "last_month"} | rest]) do
    filter(Event.last_calendar(query, "month"), rest)
  end

  defp filter(query, [{:interval, "all_time"} | rest]) do
    filter(query, rest)
  end

  defp filter(query, [{:interval, interval} | rest]) do
    {count, range} = count_and_range(interval)
    filter(Event.range(query, count, range), rest)
  end

  defp filter(query, [{:utm_sources, values} | rest]) do
    filter(Event.where_in(query, :utm_source, values), rest)
  end

  defp filter(query, [{:utm_campaigns, values} | rest]) do
    filter(Event.where_in(query, :utm_campaign, values), rest)
  end

  defp filter(query, [{:utm_mediums, values} | rest]) do
    filter(Event.where_in(query, :utm_medium, values), rest)
  end

  defp filter(query, [{:utm_contents, values} | rest]) do
    filter(Event.where_in(query, :utm_content, values), rest)
  end

  defp filter(query, [{:namespaces, values} | rest]) do
    filter(Event.where_in(query, :namespace, values), rest)
  end

  defp filter(query, [{:country_codes, values} | rest]) do
    filter(Event.where_in(query, :country_code, values), rest)
  end

  defp filter(query, [{:referrers, values} | rest]) do
    filter(Event.where_in(query, :referrer, values), rest)
  end

  defp filter(query, [{:sources, values} | rest]) do
    filter(Event.where_in(query, :referrer_source, values), rest)
  end

  defp filter(query, [{:services, values} | rest]) do
    filter(Event.where_in(query, :service_id, values), rest)
  end

  defp filter(query, [{:operating_systems, values} | rest]) do
    filter(Event.where_in(query, :operating_system, values), rest)
  end

  defp filter(query, [{:operating_system_versions, values} | rest]) do
    filter(Event.where_in(query, :operating_system_version, values), rest)
  end

  defp filter(query, [{:browsers, values} | rest]) do
    filter(Event.where_in(query, :browser, values), rest)
  end

  defp filter(query, [{:browser_versions, values} | rest]) do
    filter(Event.where_in(query, :browser_version, values), rest)
  end

  defp filter(query, [{:paths, values} | rest]) do
    filter(Event.where_in(query, :path, values), rest)
  end

  defp filter(query, [{:from, value} | rest]) do
    filter(Event.starting(query, value), rest)
  end

  defp filter(query, [{:to, value} | rest]) do
    filter(Event.ending(query, value), rest)
  end

  defp filter(query, [_ | rest]) do
    filter(query, rest)
  end

  def record([]) do
    {0, []}
  end

  def record(%Event{} = event) do
    record([event])
  end

  def record([%Event{} | _] = events) do
    now = NaiveDateTime.utc_now()

    events
    |> Enum.reduce([], fn event, acc ->
      prepared =
        event
        |> prepare_record_all()
        |> Map.put_new(:timestamp, now)

      [prepared | acc]
    end)
    |> then(&EventsRepo.insert_all(Event, &1))
  end

  def record_all(instance, maps) when is_list(maps) do
    Scouter.with_instance(instance, fn _ ->
      EventsRepo.insert_all(Event, maps)
    end)
  end

  def prepare_record_all(%Event{} = event) do
    Map.take(event, Event.__schema__(:fields))
  end

  def for_insert_all(%Event{} = event) do
    Map.take(event, Event.__schema__(:fields))
  end

  def count_and_range("past_hour"), do: {1, :hour}
  def count_and_range("past_7_days"), do: {7, :day}
  def count_and_range("past_14_days"), do: {14, :day}
  def count_and_range("past_30_days"), do: {30, :day}
  def count_and_range(_), do: {-1, :year}

  defp event_limit do
    "EVENT_LIMIT" |> System.get_env("300") |> String.to_integer()
  end
end
