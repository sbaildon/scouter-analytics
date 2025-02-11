defmodule Stats.EventsRepo.Migrations.CreateEvents do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table("events", primary_key: false) do
      add :site_id, :uuid, null: false
      add :timestamp, :naive_datetime, null: false
      add :host, :text, null: false
      add :path, :text, null: false
      add :referrer, :text
      add :utm_medium, :text
      add :utm_source, :text
      add :utm_campaign, :text
      add :utm_content, :text
      add :utm_term, :text
      add :country_code, :"varchar(2)"
      add :subdivision1_code, :text
      add :subdivision2_code, :text
      add :city_geoname_id, :text
      add :operating_system, :text
      add :operating_system_version, :text
    end
  end
end
