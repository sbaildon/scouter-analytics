defmodule Stats.Service do
  @moduledoc false
  use Stats.Schema, prefix: "service"

  import Ecto.Query

  alias Stats.Services

  schema "services" do
    field :name, :string
    field :published, :boolean
    has_many :hosts, Services.Host

    timestamps()
  end

  def changeset(service, params) do
    service
    |> cast(params, [:name, :published])
    |> validate_required([:name, :published])
  end

  defp named_binding, do: :service

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

  def where_id(query, id) do
    from([{^named_binding(), service}] in query,
      where: service.id == ^id
    )
  end

  def with_hosts(query, opts \\ []) do
    assoc = :hosts
    as = Keyword.get(opts, :as, assoc)
    from = Keyword.get(opts, :from, named_binding())

    if has_named_binding?(query, as) do
      query
    else
      from([{^from, struct}] in query,
        left_join: assoc(struct, ^assoc),
        as: ^as
      )
    end
  end
end
