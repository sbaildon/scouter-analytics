defmodule Stats.Event do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Stats.Aggregate

  require Record

  Record.defrecord(:aggregate, [:count, :grouping_id, :value, :max])

  @primary_key false
  schema "events" do
    field :site_id, :string
    field :timestamp, :naive_datetime_usec
    field :host, :string
    field :path, :string
    field :referrer, :string
    field :utm_medium, :string
    field :utm_source, :string
    field :utm_campaign, :string
    field :utm_content, :string
    field :utm_term, :string
    field :country_code, :string
    field :subdivision1_code, :string
    field :subdivision2_code, :string
    field :city_geoname_id, :integer
    field :operating_system, :string
    field :operating_system_version, :string
    field :browser, :string
    field :browser_version, :string
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(event, params) do
    event
    |> cast(params, [
      :site_id,
      :timestamp,
      :host,
      :path,
      :referrer,
      :utm_medium,
      :utm_source,
      :utm_campaign,
      :utm_content,
      :utm_term,
      :country_code,
      :subdivision1_code,
      :subdivision2_code,
      :city_geoname_id,
      :operating_system,
      :operating_system_version,
      :browser,
      :browser_version
    ])
    |> validate_format(:path, ~r/^\/.*$/)
  end

  defp named_binding, do: :event

  def query do
    from(__MODULE__, as: ^named_binding())
  end

  def scale(query, scale) do
    from([{^named_binding(), event}] in query,
      group_by: selected_as(:period),
      order_by: [asc: selected_as(:period)],
      select: %{
        count: selected_as(count("*"), :count),
        period: selected_as(fragment("date_trunc(?, ?)", ^scale, event.timestamp), :period)
      }
    )
  end

  def range(query, count, interval) do
    # not using the ago() Ecto macro because it doesn't work with DuckDB SQL
    ago = DateTime.shift(DateTime.utc_now(), [{interval, -count}])

    from([{^named_binding(), event}] in query,
      where: event.timestamp > fragment("?::TIMESTAMP_S", ^ago)
    )
  end

  def starting(query, date) do
    {:ok, normalized} = normalize_potential_iso_string(date, "00:00:00")

    from([{^named_binding(), event}] in query,
      where: event.timestamp >= fragment("?::TIMESTAMP_S", ^normalized)
    )
  end

  def ending(query, date) do
    {:ok, normalized} = normalize_potential_iso_string(date, "23:59:59")

    from([{^named_binding(), event}] in query,
      where: event.timestamp <= fragment("?::TIMESTAMP_S", ^normalized)
    )
  end

  defp normalize_potential_iso_string(potential_iso_string, time) do
    case NaiveDateTime.from_iso8601(potential_iso_string) do
      {:ok, date_time} -> {:ok, date_time}
      {:error, :invalid_format} -> NaiveDateTime.from_iso8601("#{potential_iso_string}T#{time}")
      {:error, _} = other -> other
    end
  end

  def last_calendar(query, field) do
    from([{^named_binding(), event}] in query,
      where: fragment("date_trunc(?, ?)", ^field, event.timestamp) < fragment("date_trunc(?, current_timestamp)", ^field),
      where:
        fragment("date_trunc(?, ?)", ^field, event.timestamp) >=
          fragment("date_trunc(?, current_timestamp) - ('1 ' || ?)::interval", ^field, ^field)
    )
  end

  def from_truncated_date(query, field) do
    from([{^named_binding(), event}] in query,
      where: fragment("date_trunc(?, ?) >= date_trunc(?, current_timestamp)", ^field, event.timestamp, ^field)
    )
  end

  def where_in(query, field, values) do
    {found?, values} =
      case Enum.find_index(values, &(&1 == "")) do
        nil -> {false, values}
        index -> {true, List.delete_at(values, index)}
      end

    if found? do
      from([{^named_binding(), event}] in query,
        where: field(event, ^field) in ^values,
        or_where: is_nil(field(event, ^field))
      )
    else
      from([{^named_binding(), event}] in query,
        where: field(event, ^field) in ^values
      )
    end
  end

  def count_by(query, field) do
    from([{^named_binding(), event}] in query,
      group_by: field(event, ^field),
      select: %Stats.Aggregate{count: count(field(event, ^field)), value: field(event, ^field)},
      order_by: [desc: count(field(event, ^field))]
    )
  end

  def typed_aggregate_query(query) do
    query
    |> then(fn query ->
      from([{^named_binding(), e}] in query,
        select: %{
          count: selected_as(count(), :count),
          grouping_id:
            selected_as(
              fragment(
                "GROUPING (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) :: USMALLINT",
                e.host,
                e.path,
                e.referrer,
                e.utm_medium,
                e.utm_source,
                e.utm_campaign,
                e.utm_content,
                e.utm_term,
                e.country_code,
                e.subdivision1_code,
                e.subdivision2_code,
                e.city_geoname_id,
                e.operating_system,
                e.operating_system_version,
                e.browser,
                e.browser_version
              ),
              :grouping_id
            ),
          value:
            selected_as(
              fragment(
                "CASE ?
                WHEN '0111111111111111' :: BITSTRING THEN ?
		WHEN '1011111111111111' :: BITSTRING THEN ?
		WHEN '1101111111111111' :: BITSTRING THEN ?
		WHEN '1110111111111111' :: BITSTRING THEN ?
		WHEN '1111011111111111' :: BITSTRING THEN ?
		WHEN '1111101111111111' :: BITSTRING THEN ?
		WHEN '1111110111111111' :: BITSTRING THEN ?
		WHEN '1111111011111111' :: BITSTRING THEN ?
		WHEN '1111111101111111' :: BITSTRING THEN ?
		WHEN '1111111110111111' :: BITSTRING THEN ?
		WHEN '1111111111011111' :: BITSTRING THEN ?
		WHEN '1111111111101111' :: BITSTRING THEN ?::text
		WHEN '1111111111110111' :: BITSTRING THEN ?
		WHEN '1111111111111011' :: BITSTRING THEN ?
		WHEN '1111111111111101' :: BITSTRING THEN ?
		WHEN '1111111111111110' :: BITSTRING THEN ? END",
                selected_as(:grouping_id),
                e.host,
                e.path,
                e.referrer,
                e.utm_medium,
                e.utm_source,
                e.utm_campaign,
                e.utm_content,
                e.utm_term,
                e.country_code,
                e.subdivision1_code,
                e.subdivision2_code,
                e.city_geoname_id,
                e.operating_system,
                e.operating_system_version,
                e.browser,
                e.browser_version
              ),
              :value
            ),
          max: over(max(selected_as(:count)), partition_by: selected_as(:grouping_id))
        }
      )
    end)
    |> then(fn query ->
      from([{^named_binding(), e}] in query,
        group_by:
          fragment(
            "GROUPING SETS((?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?))",
            e.host,
            e.path,
            e.referrer,
            e.utm_medium,
            e.utm_source,
            e.utm_campaign,
            e.utm_content,
            e.utm_term,
            e.country_code,
            e.subdivision1_code,
            e.subdivision2_code,
            e.city_geoname_id,
            e.operating_system,
            e.operating_system_version,
            e.browser,
            e.browser_version
          )
      )
    end)
    |> then(fn query ->
      from([{^named_binding(), event}] in query,
        order_by: [asc: selected_as(:grouping_id), desc: selected_as(:count)]
      )
    end)
  end

  def aggregate_query(query) do
    query
    |> then(fn query ->
      from([{^named_binding(), e}] in query,
        select: %Aggregate{
          grouping_id:
            selected_as(
              fragment(
                "GROUPING (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                e.host,
                e.path,
                e.referrer,
                e.utm_medium,
                e.utm_source,
                e.utm_campaign,
                e.utm_content,
                e.utm_term,
                e.country_code,
                e.subdivision1_code,
                e.subdivision2_code,
                e.city_geoname_id,
                e.operating_system,
                e.operating_system_version,
                e.browser,
                e.browser_version
              ),
              :grouping_id
            ),
          count: count(),
          host: e.host,
          path: e.path,
          referrer: e.referrer,
          utm_medium: e.utm_medium,
          utm_source: e.utm_source,
          utm_campaign: e.utm_campaign,
          utm_content: e.utm_content,
          utm_term: e.utm_term,
          country_code: e.country_code,
          subdivision1_code: e.subdivision1_code,
          subdivision2_code: e.subdivision2_code,
          city_geoname_id: e.city_geoname_id,
          operating_system: e.operating_system,
          operating_system_version: e.operating_system_version,
          browser: e.browser,
          browser_version: e.browser_version
        }
      )
    end)
    |> then(fn query ->
      from([{^named_binding(), e}] in query,
        group_by:
          fragment(
            "GROUPING SETS((?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?), (?))",
            e.host,
            e.path,
            e.referrer,
            e.utm_medium,
            e.utm_source,
            e.utm_campaign,
            e.utm_content,
            e.utm_term,
            e.country_code,
            e.subdivision1_code,
            e.subdivision2_code,
            e.city_geoname_id,
            e.operating_system,
            e.operating_system_version,
            e.browser,
            e.browser_version
          )
      )
    end)
    |> then(fn query ->
      from([{^named_binding(), event}] in query,
        order_by: [asc: selected_as(:grouping_id), desc: :count]
      )
    end)
  end

  # keep in mind
  # Note that that query will be pretty slow.
  # A better idea would be to do
  #
  # mydate >= date_trunc('year',current_date) AND
  # mydate < date_trunc(~c"year", current_date + interval(~c"1 year"))
end
