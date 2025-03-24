defmodule Stats.EventsRepo.Migrations.CreateEvents do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table("events", primary_key: false) do
      add :service_id, :uuid, null: false
      add :timestamp, :naive_datetime, null: false
      add :namespace, :text, null: false
      add :path, :text, null: false
      add :referrer, :text
      add :referrer_source, :text
      add :utm_medium, :text
      add :utm_source, :text
      add :utm_campaign, :text
      add :utm_content, :text
      add :utm_term, :text
      add :country_code, :"varchar(2)"
      add :subdivision1_code, :text
      add :subdivision2_code, :text
      add :city_geoname_id, :integer
      add :operating_system, :text
      add :operating_system_version, :text
      add :browser, :text
      add :browser_version, :text
    end
  end
end
