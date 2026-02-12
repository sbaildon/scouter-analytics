defmodule Scouter.EventsRepo.Migrations.CreatePageViewsView do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE VIEW web_analytics AS
    SELECT
    service_id,
    timestamp,
    properties->>'namespace' AS namespace,
    properties->>'path' AS path,
    properties->>'referrer' AS referrer,
    properties->>'referrer_source' AS referrer_source,
    properties->>'utm_medium' AS utm_medium,
    properties->>'utm_source' AS utm_source,
    properties->>'utm_campaign' AS utm_campaign,
    properties->>'utm_content' AS utm_content,
    properties->>'country_code' AS country_code,
    properties->>'operating_system' AS operating_system,
    properties->>'operating_system_version' AS operating_system_version,
    properties->>'browser' AS browser,
    properties->>'browser_version' AS browser_version
    FROM events WHERE events.type = 'pageview';
    """)
  end

  def down do
    execute("DROP VIEW web_analytics")
  end
end
