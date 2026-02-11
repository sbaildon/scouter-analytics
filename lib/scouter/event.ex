defmodule Scouter.Event do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  import Scouter.Events.GroupingID

  alias Scouter.Cldr.Territory

  require Record

  Record.defrecord(:aggregate, [:count, :grouping_id, :value, :max])

  @primary_key false
  schema "events" do
    field :service_id, :string
    field :timestamp, :naive_datetime
    field :type, :string
    field :properties, Ecto.JSON
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(event, params) do
    event
    |> cast(params, [
      :service_id,
      :timestamp,
      :namespace,
      :path,
      :referrer,
      :referrer_source,
      :utm_medium,
      :utm_source,
      :utm_campaign,
      :utm_content,
      :utm_term,
      :country_code,
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

  defmacro interval(count, interval) do
    quote do
      fragment("(? || '' || ?)::interval", unquote(count), ^Atom.to_string(unquote(interval)))
    end
  end

  defmacro date_trunc(part, date) do
    quote do
      fragment("date_trunc(?, ?)", unquote(part), unquote(date))
    end
  end

  defmacro current_localtimestamp() do
    quote do
      fragment("current_localtimestamp()")
    end
  end

  def range(query, count, interval) do
    from([{^named_binding(), event}] in query,
      where:
        event.timestamp >=
          date_trunc("minute", current_localtimestamp()) - interval(^count, interval)
    )
  end

  def starting(query, date) do
    {:ok, normalized} = normalize_potential_iso_string(date, "00:00:00")

    from([{^named_binding(), event}] in query,
      where: event.timestamp >= fragment("?::TIMESTAMP_S", ^NaiveDateTime.to_string(normalized))
    )
  end

  def ending(query, date) do
    {:ok, normalized} = normalize_potential_iso_string(date, "23:59:59")

    from([{^named_binding(), event}] in query,
      where: event.timestamp <= fragment("?::TIMESTAMP_S", ^NaiveDateTime.to_string(normalized))
    )
  end

  defp normalize_potential_iso_string(%DateTime{} = datetime, _time) do
    {:ok, DateTime.to_naive(datetime)}
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
      where:
        fragment("timezone('UTC', ?)", event.timestamp) <
          fragment("date_trunc(?, current_timestamp)", ^field),
      where:
        fragment("timezone('UTC', ?)", event.timestamp) >=
          fragment("date_trunc(?, current_timestamp) - ('1 ' || ?)::interval", ^field, ^field)
    )
  end

  def from_truncated_date(query, field) do
    from([{^named_binding(), event}] in query,
      where:
        fragment(
          "timezone('UTC', ?) >= date_trunc(?, current_timestamp)",
          event.timestamp,
          ^field
        )
    )
  end

  def where_in(query, field, values) do
    {allow_null?, values} =
      case Enum.find_index(values, &(&1 == "")) do
        nil -> {false, values}
        index -> {true, List.delete_at(values, index)}
      end

    if allow_null? do
      from([{^named_binding(), event}] in query,
        where: field(event, ^field) in ^values or is_nil(field(event, ^field))
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
      select: %Scouter.Aggregate{count: count(field(event, ^field)), value: field(event, ^field)},
      order_by: [desc: count(field(event, ^field))]
    )
  end

  def present(_, nil), do: unknown()
  def present(_, ""), do: unknown()

  def present(group_id(:country_code), nil), do: unknown()

  def present(group_id(:country_code), country_code) do
    case Territory.from_territory_code(country_code) do
      {:ok, name} -> name
      {:error, _} -> country_code
    end
  end

  def present(group_id(:referrer), value) do
    case URI.parse(value) do
      %{scheme: nil, host: nil, path: nil} -> unknown()
      %{scheme: nil, host: nil, path: path} -> path
      %{host: host} -> host
      _ -> unknown()
    end
  end

  def present(_, value), do: value

  defp unknown, do: "<Unknown>"

  # keep in mind
  # Note that that query will be pretty slow.
  # A better idea would be to do
  #
  # mydate >= date_trunc('year',current_date) AND
  # mydate < date_trunc(~c"year", current_date + interval(~c"1 year"))
end
