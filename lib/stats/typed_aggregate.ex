defmodule Stats.TypedAggregate do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  alias Stats.Cldr.Territory
  @primary_key false
  embedded_schema do
    field :count, :integer

    field :grouping_id, Ecto.Enum,
      values: [
        host: 0b0111111111111111,
        path: 0b1011111111111111,
        referrer: 0b1101111111111111,
        utm_medium: 0b1110111111111111,
        utm_source: 0b1111011111111111,
        utm_campaign: 0b1111101111111111,
        utm_content: 0b1111110111111111,
        utm_term: 0b1111111011111111,
        country_code: 0b1111111101111111,
        subdivision1_code: 0b1111111110111111,
        subdivision2_code: 0b1111111111011111,
        city_geoname_id: 0b1111111111101111,
        operating_system: 0b1111111111110111,
        operating_system_version: 0b1111111111111011,
        browser: 0b1111111111111101,
        browser_version: 0b1111111111111110
      ]

    field :value, :string
  end

  def changeset(typed_aggregate, params) do
    cast(typed_aggregate, params, [:count, :grouping_id, :value])
  end

  defimpl Stats.Queryable do
    import Stats.Aggregates.GroupingId

    def present(%{grouping_id: :country_code, value: nil}), do: "Unknown"
    def present(%{grouping_id: :country_code, value: country_code}), do: Territory.from_territory_code!(country_code)

    def present(%{grouping_id: :referrer, value: nil}), do: "Unknown"

    def present(%{grouping_id: :referrer, value: value}) do
      value |> URI.parse() |> Map.fetch!(:host) |> then(fn host -> Regex.replace(~r/(www\.)/, host, "") end)
    end

    def present(%{value: value}), do: value

    def hash(%{value: value}) do
      :erlang.phash2(value)
    end
  end
end
