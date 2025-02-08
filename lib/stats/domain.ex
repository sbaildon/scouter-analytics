defmodule Stats.Domain do
  @moduledoc false
  use Stats.Schema, prefix: "domain"

  schema "domains" do
    field :host, :string

    timestamps()
  end

  def changeset(domain, params) do
    domain
    |> cast(params, [:host])
    |> validate_required([:host])
  end
end
