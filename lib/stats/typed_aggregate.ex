defmodule Stats.TypedAggregate do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Stats.Events.GroupingID

  alias Stats.Cldr.Territory

  @primary_key false
  embedded_schema do
    field :count, :integer

    field :grouping_id, Ecto.Enum,
      values: [
        host: group_id(:host),
        path: group_id(:path),
        referrer: group_id(:referrer),
        utm_medium: group_id(:utm_medium),
        utm_source: group_id(:utm_source),
        utm_campaign: group_id(:utm_campaign),
        utm_content: group_id(:utm_content),
        utm_term: group_id(:utm_term),
        country_code: group_id(:country_code),
        subdivision1_code: group_id(:subdivision1_code),
        subdivision2_code: group_id(:subdivision2_code),
        city_geoname_id: group_id(:city_geoname_id),
        operating_system: group_id(:operating_system),
        operating_system_version: group_id(:operating_system_version),
        browser: group_id(:browser),
        browser_version: group_id(:browser_version)
      ]

    field :value, :string
  end

  def changeset(typed_aggregate, params) do
    cast(typed_aggregate, params, [:count, :grouping_id, :value])
  end

  defimpl Stats.Queryable do
    def present(%{grouping_id: :country_code, value: nil}), do: "Unknown"
    def present(%{grouping_id: :country_code, value: country_code}), do: Territory.from_territory_code!(country_code)

    def present(%{grouping_id: :referrer, value: nil}), do: "Unknown"

    def present(%{grouping_id: :referrer, value: value}) do
      value |> URI.parse() |> Map.fetch!(:host) |> then(fn host -> Regex.replace(~r/(www\.)/, host, "") end)
    end

    def present(%{value: value}), do: value

    def hash(%{grouping_id: grouping_id, value: value}) do
      :erlang.phash2({grouping_id, value})
    end

    def value(%{value: value}), do: value
    def count(%{count: count}), do: count
  end
end
