defmodule Stats.Service do
  @moduledoc false
  use Schema, prefix: "service"

  import Ecto.Query

  alias Stats.Services

  schema "services" do
    field :name, :string
    field :published, :boolean, default: true
    field :public, :boolean, default: false
    has_many :providers, Services.Provider

    timestamps()
  end

  def changeset(service, params) do
    service
    |> cast(params, [:name, :published, :public])
    |> validate_required([:name, :published, :public])
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

  def where_id(query, ids) when is_list(ids) do
    from([{^named_binding(), service}] in query,
      where: service.id in ^ids
    )
  end

  def where_id(query, id) do
    from([{^named_binding(), service}] in query,
      where: service.id == ^id
    )
  end

  def with_providers(query, opts \\ []) do
    assoc = :providers
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
