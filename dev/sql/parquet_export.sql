COPY 'events' TO 'events' (
    FORMAT parquet,
    COMPRESSION zstd,
    PARTITION_BY (timestamp)
) COPY (
    SELECT
        *,
        YEAR(timestamp) AS 'year',
        MONTH(timestamp) AS 'month'
    FROM
        EVENTS
) TO 'out' (
    FORMAT parquet,
    OVERWRITE_OR_IGNORE,
    PARTITION_BY ('year', 'month')
);
