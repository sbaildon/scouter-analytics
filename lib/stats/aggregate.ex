defmodule Stats.Aggregate do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :count, :integer
    field :value, :string
  end
end
