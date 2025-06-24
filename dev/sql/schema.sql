CREATE TABLE events(site_id UUID, "timestamp" TIMESTAMP_S NOT NULL, host VARCHAR NOT NULL, path VARCHAR NOT NULL, referrer VARCHAR, utm_medium VARCHAR, utm_source VARCHAR, utm_campaign VARCHAR, utm_content VARCHAR, utm_term VARCHAR, country_code VARCHAR, subdivision1_code VARCHAR, subdivision2_code VARCHAR, city_geoname_id INTEGER, operating_system VARCHAR, operating_system_version VARCHAR, browser VARCHAR, browser_version VARCHAR);
CREATE TABLE schema_migrations("version" BIGINT, inserted_at TIMESTAMP_S, PRIMARY KEY("version"));

