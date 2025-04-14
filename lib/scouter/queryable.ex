defprotocol Scouter.Queryable do
  def present(value)
  def hash(value)
  def count(value)
  def value(value)
end

defimpl Scouter.Queryable, for: Tuple do
  import Scouter.Event, only: [aggregate: 1]
  import Scouter.Events.GroupingID

  def hash(aggregate(grouping_id: grouping_id, value: value)) do
    :erlang.phash2({grouping_id, value})
  end

  def hash({group_id, ""}) do
    :erlang.phash2({group_id, nil})
  end

  def hash({group_id, value}) do
    :erlang.phash2({group_id, value})
  end

  def present(aggregate(value: nil)), do: "<Unknown>"
  def present(aggregate(value: "")), do: "<Unknown>"

  def present(aggregate(grouping_id: group_id(:referrer), value: value)) do
    normalize_potential_uri(value)
  end

  def present(aggregate(grouping_id: group_id(:country_code), value: value)),
    do: Scouter.Cldr.Territory.from_territory_code!(value)

  def present(aggregate(value: value)), do: value

  def value(aggregate(value: value)), do: value
  def count(aggregate(count: count)), do: count

  defp normalize_potential_uri(value) do
    case_result =
      case value do
        "https://" <> _ = uri -> uri
        "http://" <> _ = uri -> uri
        schemaless -> "invalid://#{schemaless}"
      end

    case_result |> URI.parse() |> Map.fetch!(:host) |> String.trim_leading("www.")
  end
end
