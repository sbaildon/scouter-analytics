defmodule Stats.Event do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

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
  end

  def changeset(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(event, params) do
    cast(event, params, [
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
      :operating_system_version
    ])
  end
end
