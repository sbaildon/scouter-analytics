defmodule Scouter.Service do
  @moduledoc false
  use Schema, prefix: "service"

  import Ecto.Query

  alias Scouter.Services

  schema "services" do
    field :name, :string
    field :published, :boolean, default: true
    has_many :matchers, Services.Matcher, defaults: :inherit_account_id, on_replace: :delete

    timestamps()
  end

  def changeset(service, params) do
    service
    |> cast(params, [:name, :published])
    |> validate_required([:name, :published])
    |> cast_assoc(:matchers)
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

  def where_name(query, name) do
    from([{^named_binding(), service}] in query,
      where: service.name == ^name
    )
  end

  def with_matchers(query, opts \\ []) do
    assoc = :matchers
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

  def set_primary_provider(service, provider_id) do
    Ecto.Changeset.change(service, primary_provider_id: provider_id)
  end

  defimpl Phoenix.Param do
    def to_param(service) do
      service.id
    end
  end
end
