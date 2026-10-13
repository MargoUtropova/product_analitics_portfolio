CREATE SCHEMA IF NOT EXISTS etl;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE TABLE etl.params AS
SELECT
DATE_TRUNC('month', (SELECT MIN(datetime)::date FROM checks) + INTERVAL '1 month')::date AS cohort_start,-- первая когорта
DATE_TRUNC('month', (SELECT MAX(datetime)::date FROM checks) - INTERVAL '1 month')::date AS data_end_month -- последний ПОЛНЫЙ день данных