defmodule Stats.Domain do
  @moduledoc false
  use Stats.Schema, prefix: "domain"

  import Ecto.Query

  schema "domains" do
    field :host, :string
    field :published, :boolean

    timestamps()
  end

  def changeset(domain, params) do
    domain
    |> cast(params, [:host])
    |> validate_required([:host])
  end

  defp named_binding, do: :domain

  def query do
    from(__MODULE__, as: ^named_binding())
  end

  def where_published(query) do
    from([{^named_binding(), domain}] in query,
      where: domain.published == true
    )
  end
end
