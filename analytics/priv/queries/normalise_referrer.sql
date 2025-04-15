-- extract only the host from referrer
BEGIN TRANSACTION;

UPDATE
    'events'
SET
    referrer = regexp_extract(
        referrer,
        '(https?:\/\/)(www.)?([^\/\?#:]+)',
        ['scheme', 'www', 'host']
    ).host
WHERE
    regexp_matches(referrer, 'https?://');

SELECT
    referrer
FROM
    'events'
WHERE
    referrer IS NOT NULL;

ROLLBACK TRANSACTION;
