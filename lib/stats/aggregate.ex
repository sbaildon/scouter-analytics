defmodule Stats.Aggregate do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :grouping_id, :binary
    field :count, :integer
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

  def hash(%{grouping_id: 0b011111111111111111, site_id: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b101111111111111111, timestamp: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b110111111111111111, host: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111011111111111111, path: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111101111111111111, referrer: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111110111111111111, utm_medium: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111011111111111, utm_source: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111101111111111, utm_campaign: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111110111111111, utm_content: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111111011111111, utm_term: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111111101111111, country_code: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111111110111111, subdivision1_code: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111111111011111, subdivision2_code: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111111111101111, city_geoname_id: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111111111110111, operating_system: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111111111111011, operating_system_version: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111111111111101, browser: field}), do: do_hash(field)
  def hash(%{grouping_id: 0b111111111111111110, browser_version: field}), do: do_hash(field)

  defp do_hash(term), do: :erlang.phash2(term)

  def field(%{grouping_id: 0b011111111111111111}), do: :site_id
  def field(%{grouping_id: 0b101111111111111111}), do: :timestamp
  def field(%{grouping_id: 0b110111111111111111}), do: :host
  def field(%{grouping_id: 0b111011111111111111}), do: :path
  def field(%{grouping_id: 0b111101111111111111}), do: :referrer
  def field(%{grouping_id: 0b111110111111111111}), do: :utm_medium
  def field(%{grouping_id: 0b111111011111111111}), do: :utm_source
  def field(%{grouping_id: 0b111111101111111111}), do: :utm_campaign
  def field(%{grouping_id: 0b111111110111111111}), do: :utm_content
  def field(%{grouping_id: 0b111111111011111111}), do: :utm_term
  def field(%{grouping_id: 0b111111111101111111}), do: :country_code
  def field(%{grouping_id: 0b111111111110111111}), do: :subdivision1_code
  def field(%{grouping_id: 0b111111111111011111}), do: :subdivision2_code
  def field(%{grouping_id: 0b111111111111101111}), do: :subdivision2_code
  def field(%{grouping_id: 0b111111111111110111}), do: :operating_system
  def field(%{grouping_id: 0b111111111111111011}), do: :operating_system_version
  def field(%{grouping_id: 0b111111111111111101}), do: :browser
  def field(%{grouping_id: 0b111111111111111110}), do: :browser_version
end
