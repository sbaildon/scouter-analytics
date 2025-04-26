COPY events FROM 'backups/events.parquet' (FORMAT 'parquet');
COPY schema_migrations FROM 'backups/schema_migrations.parquet' (FORMAT 'parquet');
