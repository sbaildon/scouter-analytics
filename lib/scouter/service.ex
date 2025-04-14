defmodule Scouter.Service do
  @moduledoc false
  use Schema, prefix: "service"

  import Ecto.Query

  alias Scouter.Services

  schema "services" do
    field :published, :boolean, default: true
    has_many :providers, Services.Provider
    belongs_to :primary_provider, Services.Provider

    timestamps()
  end

  def changeset(service, params) do
    service
    |> cast(params, [:published])
    |> validate_required([:published])
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

  def where_shared(query) do
    from([{^named_binding(), domain}] in query,
      where: domain.published
    )
  end

  def where_id(id) do
    where_id(query(), id)
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

  def with_primary_provider(query, opts \\ []) do
    assoc = :primary_provider
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

  def name(%{primary_provider: provider}) do
    provider.namespace
  end

  def set_primary_provider(service, provider_id) do
    Ecto.Changeset.change(service, primary_provider_id: provider_id)
  end

  defimpl Phoenix.Param do
    def to_param(service) do
      Scouter.Service.name(service)
    end
  end
end
