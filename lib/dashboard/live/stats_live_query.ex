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
    field :scale, Ecto.Enum, values: [:day, :week, :month, :year]
    embeds_one :period, Dashboard.StatsLive.Period
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
    |> cast(params, castable())
    |> cast_embed(:period)
    |> apply_action(:validate)
  end
end
