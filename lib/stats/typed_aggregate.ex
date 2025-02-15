defmodule Stats.TypedAggregate do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :count, :integer
    field :grouping_id, :binary
    field :value, :string
  end

  def hash(%{value: value}), do: :erlang.phash2(value)
end
