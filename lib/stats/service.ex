defmodule Stats.Service do
  @moduledoc false
  use Stats.Schema, prefix: "service"

  import Ecto.Query

  schema "services" do
    field :name, :string
    field :published, :boolean

    timestamps()
  end

  def changeset(service, params) do
    service
    |> cast(params, [:name, :published])
    |> validate_required([:name, :published])
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

  def where_name(query, name) do
    from([{^named_binding(), domain}] in query,
      where: domain.name == ^name
    )
  end
end
