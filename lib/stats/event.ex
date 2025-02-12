defmodule Stats.Event do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  @primary_key false
  schema "events" do
    field :site_id, TypeID, prefix: "site", type: :uuid
    field :timestamp, :naive_datetime_usec
    field :host, :string
    field :path, :string
    field :referrer, :string
    field :utm_medium, :string
    field :utm_source, :string
    field :utm_campaign, :string
    field :utm_content, :string
    field :utm_term, :string
    field :country_code, :string
    field :subdivision1_code, :string
    field :subdivision2_code, :string
    field :city_geoname_id, :integer
    field :operating_system, :string
    field :operating_system_version, :string
    field :browser, :string
    field :browser_version, :string
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(event, params) do
    event
    |> cast(params, [
      :site_id,
      :timestamp,
      :host,
      :path,
      :referrer,
      :utm_medium,
      :utm_source,
      :utm_campaign,
      :utm_content,
      :utm_term,
      :country_code,
      :subdivision1_code,
      :subdivision2_code,
      :city_geoname_id,
      :operating_system,
      :operating_system_version,
      :browser,
      :browser_version
    ])
    |> validate_format(:path, ~r/^\/.*$/)
  end

  defp named_binding, do: :event

  def query do
    from(__MODULE__, as: ^named_binding())
  end

  def hourly(query) do
    from([{^named_binding(), event}] in query,
      group_by: fragment("date_trunc('hour', ?)", event.timestamp),
      order_by: [asc: fragment("date_trunc('hour', ?)", event.timestamp)],
      select: %{count: count("*"), hour: fragment("date_trunc('hour', ?)", event.timestamp)}
    )
  end

  def where_in(query, field, values) do
    from([{^named_binding(), event}] in query,
      where: field(event, ^field) in ^values
    )
  end

  def count_by(query, field) do
    from([{^named_binding(), event}] in query,
      group_by: field(event, ^field),
      select: %Stats.Aggregate{count: count(field(event, ^field)), value: field(event, ^field)},
      order_by: [desc: count(field(event, ^field))]
    )
  end
end
