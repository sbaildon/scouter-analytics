defprotocol Stats.Queryable do
  def present(value)
  def hash(value)
  def count(value)
  def value(value)
end

defimpl Stats.Queryable, for: Tuple do
  import Stats.Event, only: [aggregate: 1]
  import Stats.Events.GroupingID

  def hash(aggregate(grouping_id: grouping_id, value: value)) do
    :erlang.phash2({grouping_id, value})
  end

  def hash({group_id, value}) do
    :erlang.phash2({group_id, value})
  end

  def present(aggregate(value: nil)), do: "<Unknown>"

  def present(aggregate(grouping_id: group_id(:referrer), value: value)),
    do: value |> URI.parse() |> Map.fetch!(:host) |> then(fn host -> Regex.replace(~r/(www\.)/, host, "") end)

  def present(aggregate(grouping_id: group_id(:country_code), value: value)),
    do: Stats.Cldr.Territory.from_territory_code!(value)

  def present(aggregate(value: value)), do: value

  def value(aggregate(value: value)), do: value
  def count(aggregate(count: count)), do: count
end
