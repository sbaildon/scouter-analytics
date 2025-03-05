defmodule Dashboard.StatsLive.Query do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :sites, {:array, :string}
    field :browsers, {:array, :string}
    field :browser_versions, {:array, :string}
    field :paths, {:array, :string}
    field :hosts, {:array, :string}
    field :operating_systems, {:array, :string}
    field :operating_system_versions, {:array, :string}
    field :referrers, {:array, :string}
    field :utm_sources, {:array, :string}
    field :utm_campaigns, {:array, :string}
    field :utm_mediums, {:array, :string}
    field :utm_contents, {:array, :string}
    field :utm_terms, {:array, :string}
    field :country_codes, {:array, :string}
    field :scale, :string, default: "day"
    field :interval, :string
    field :from, :string
    field :to, :string
  end

  defp castable do
    fields = __MODULE__.__schema__(:fields)
    embeds = __MODULE__.__schema__(:embeds)
    fields -- embeds
  end

  def validate(params) when is_map(params) do
    validate(%__MODULE__{}, params)
  end

  def validate(query, params) do
    query
    |> cast(params, castable(), empty_values: [nil])
    |> validate_inclusion(:scale, scale_values())
    |> apply_action(:validate)
  end

  def scale, do: [{"Hour", "hour"}, {"Day", "day"}, {"Week", "week"}, {"Month", "month"}, {"Year", "year"}]
  defp scale_values, do: Enum.map(scale(), &elem(&1, 1))

  def periods do
    [
      [{"Live", "live", "l"}, {"Past Hour", "past_hour", "h"}, {"Today", "today", "t"}, {"Yesterday", "yesterday", "y"}],
      [{"Month to Date", "month_to_date", "m"}, {"Last Month", "last_month", "L M"}],
      [{"Year to Date", "year_to_date", "y d"}, {"Last Year", "last_year", "Shift+Y"}],
      [
        {"Past 7 Days", "past_7_days", "p w"},
        {"Past 14 Days", "past_14_days", "p f"},
        {"Past 30 Days", "past_30_days", "p m"}
      ],
      [{"All Time", "all_time", "A"}]
    ]
  end

  def to_filters(query) do
    query
    |> Map.from_struct()
    |> Enum.to_list()
  end
end
