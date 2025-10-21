defmodule Scouter.Services.Matcher do
  use Schema, prefix: "service_matcher"

  import Ecto.Query

  alias Scouter.Service

  schema "service_matchers" do
    belongs_to :service, Service
    field :pattern, Ecto.Regex

    timestamps()
  end

  def changeset(matcher, params) do
    matcher
    |> cast(params, [:service_id, :pattern])
    |> validate_required(:pattern)
  end
end
