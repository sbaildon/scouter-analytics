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

  def hash(%{grouping_id: 131_071, site_id: field}), do: do_hash(field)
  def hash(%{grouping_id: 196_607, timestamp: field}), do: do_hash(field)
  def hash(%{grouping_id: 229_375, host: field}), do: do_hash(field)
  def hash(%{grouping_id: 245_759, path: field}), do: do_hash(field)
  def hash(%{grouping_id: 253_951, referrer: field}), do: do_hash(field)
  def hash(%{grouping_id: 258_047, utm_medium: field}), do: do_hash(field)
  def hash(%{grouping_id: 260_095, utm_source: field}), do: do_hash(field)
  def hash(%{grouping_id: 261_119, utm_campaign: field}), do: do_hash(field)
  def hash(%{grouping_id: 261_631, utm_content: field}), do: do_hash(field)
  def hash(%{grouping_id: 261_887, utm_term: field}), do: do_hash(field)
  def hash(%{grouping_id: 262_015, country_code: field}), do: do_hash(field)
  def hash(%{grouping_id: 262_079, subdivision1_code: field}), do: do_hash(field)
  def hash(%{grouping_id: 262_111, subdivision2_code: field}), do: do_hash(field)
  def hash(%{grouping_id: 262_127, city_geoname_id: field}), do: do_hash(field)
  def hash(%{grouping_id: 262_135, operating_system: field}), do: do_hash(field)
  def hash(%{grouping_id: 262_139, operating_system_version: field}), do: do_hash(field)
  def hash(%{grouping_id: 262_141, browser: field}), do: do_hash(field)
  def hash(%{grouping_id: 262_142, browser_version: field}), do: do_hash(field)

  defp do_hash(term), do: :erlang.phash2(term)

  def field(%{grouping_id: 131_071}), do: :site_id
  def field(%{grouping_id: 196_607}), do: :timestamp
  def field(%{grouping_id: 229_375}), do: :host
  def field(%{grouping_id: 245_759}), do: :path
  def field(%{grouping_id: 253_951}), do: :referrer
  def field(%{grouping_id: 258_047}), do: :utm_medium
  def field(%{grouping_id: 260_095}), do: :utm_source
  def field(%{grouping_id: 261_119}), do: :utm_campaign
  def field(%{grouping_id: 261_631}), do: :utm_content
  def field(%{grouping_id: 261_887}), do: :utm_term
  def field(%{grouping_id: 262_015}), do: :country_code
  def field(%{grouping_id: 262_079}), do: :subdivision1_code
  def field(%{grouping_id: 262_111}), do: :subdivision2_code
  def field(%{grouping_id: 262_127}), do: :subdivision2_code
  def field(%{grouping_id: 262_135}), do: :operating_system
  def field(%{grouping_id: 262_139}), do: :operating_system_version
  def field(%{grouping_id: 262_141}), do: :browser
  def field(%{grouping_id: 262_142}), do: :browser_version
end
