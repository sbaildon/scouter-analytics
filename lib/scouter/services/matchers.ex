defmodule Scouter.Services.Matcher do
  @moduledoc false
  use Schema, prefix: "service_matcher"

  import Ecto.Query

  alias Scouter.Service

  schema "service_matchers" do
    belongs_to :service, Service
    field :value, :string
    field :type, Ecto.Enum, values: [:regex, :exact, :wildcard]
    field :regex, Ecto.Regex, virtual: true
    timestamps()
  end

  def changeset(matcher, params) do
    matcher
    |> cast(params, [:value, :type])
    |> validate_required([:value, :type])
  end

  defp named_binding, do: :matcher

  def query do
    from(__MODULE__, as: ^named_binding())
  end

  def where_service(service_id) do
    where_service(query(), service_id)
  end

  def where_service(query, service_id) do
    from([{^named_binding(), struct}] in query,
      where: struct.service_id == ^service_id
    )
  end
end
