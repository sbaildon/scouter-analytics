defmodule Telemetry.Count do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Telemetry.Count

  @primary_key false
  embedded_schema do
    field :b, :boolean
    field :q, Count.QueryParams
    field :p, Count.Path
    field :r, :string
  end

  def changeset(count, params) do
    cast(count, params, [:b, :p, :q, :r])
  end

  def validate(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action(:accept)
  end
end
