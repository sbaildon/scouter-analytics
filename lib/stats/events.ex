defmodule Stats.Events do
  @moduledoc false
  alias Stats.Event
  alias Stats.EventsRepo
  alias Stats.Geo

  require Logger

  def scale(scale, filters \\ []) do
    Event.query()
    |> Event.scale(scale)
    |> filter(filters)
    |> EventsRepo.arrow_query()
  end

  def retrieve(count_by, filters \\ []) do
    Event.query()
    |> Event.count_by(count_by)
    |> filter(filters)
    |> EventsRepo.arrow_query()
  end

  def stream_aggregates(filters \\ []) do
    Event.query()
    |> Event.typed_aggregate_query()
    |> filter(filters)
    |> EventsRepo.arrow_stream()
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

  defp filter(query, [{:utm_terms, values} | rest]) do
    filter(Event.where_in(query, :utm_term, values), rest)
  end

  defp filter(query, [{:country_codes, values} | rest]) do
    filter(Event.where_in(query, :country_code, values), rest)
  end

  defp filter(query, [{:referrers, values} | rest]) do
    filter(Event.where_in(query, :referrer, values), rest)
  end

  defp filter(query, [{:sites, values} | rest]) do
    filter(Event.where_in(query, :site_id, values), rest)
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

  def record(events) when is_list(events) do
    now = NaiveDateTime.utc_now()

    events
    |> Enum.map(fn event ->
      event
      |> Map.from_struct()
      |> Map.delete(:__meta__)
      |> Map.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.put_new(:timestamp, now)
    end)
    |> then(&EventsRepo.insert_all(Event, &1))
  end

  def record(%Event{} = event) do
    now = NaiveDateTime.utc_now()

    events =
      for _i <- 1..Enum.random(51..200) do
        event
        |> Map.replace(:site_id, TypeID.new("site"))
        |> Map.put_new(:timestamp, now)
        |> Map.from_struct()
        |> Map.delete(:__meta__)
      end

    EventsRepo.insert_all(Event, events)
  end

  def count_and_range("past_hour"), do: {1, :hour}
  def count_and_range("past_7_days"), do: {7, :day}
  def count_and_range("past_14_days"), do: {14, :day}
  def count_and_range("past_30_days"), do: {30, :day}
  def count_and_range(_), do: {-1, :year}

  def country_details(event, ip) do
    geo_params =
      case Geo.lookup(ip) do
        %{} = entry ->
          country_code =
            entry
            |> get_in(["country", "iso_code"])
            |> ignore_unknown_country()

          city_geoname_id = country_code && get_in(entry, ["city", "geoname_id"])

          %{
            country_code: country_code,
            subdivision1_code: subdivision1_code(country_code, entry),
            subdivision2_code: subdivision2_code(country_code, entry),
            city_geoname_id: city_geoname_id
          }

        nil ->
          %{}
      end

    Map.merge(event, geo_params)
  end

  defp subdivision1_code(country_code, %{"subdivisions" => [%{"iso_code" => iso_code} | _rest]})
       when not is_nil(country_code) do
    country_code <> "-" <> iso_code
  end

  defp subdivision1_code(_, _), do: nil

  defp subdivision2_code(country_code, %{"subdivisions" => [_first, %{"iso_code" => iso_code} | _rest]})
       when not is_nil(country_code) do
    country_code <> "-" <> iso_code
  end

  defp subdivision2_code(_, _), do: nil

  # Ignore worldwide (ZZ), disputed terrories (XX), and Tor (T1)
  defp ignore_unknown_country("ZZ"), do: nil
  defp ignore_unknown_country("XX"), do: nil
  defp ignore_unknown_country("T1"), do: nil
  defp ignore_unknown_country(country), do: country
end
