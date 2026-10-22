-- =====================================================================
-- 01_params.sql: параметры расчёта (PostgreSQL)
-- =====================================================================
-- Запускать первым: от etl.params зависят etl.orders и всё, что построено на нём.
--   cohort_start    — первая полная когорта (1-е число месяца после начала данных)
--   data_end        — последний день данных (нужен для окон, зрелости и фильтра заказов)
--   data_end_month  — месяц последней ПОЛНОЙ когорты (1-е число)

CREATE SCHEMA IF NOT EXISTS etl;
CREATE SCHEMA IF NOT EXISTS mart;

-- CASCADE удалит зависимые представления (etl.orders и др.): их пересоздают следующие файлы.
DROP TABLE IF EXISTS etl.params CASCADE;

CREATE TABLE etl.params AS
WITH b AS (
	SELECT
		MIN(datetime::date) AS min_date,
		MAX(datetime::date) AS data_end      -- если последний день неполный: MAX(datetime::date) - 1
	FROM checks
	WHERE card LIKE '2000%'
)
SELECT
	DATE_TRUNC('month', min_date + INTERVAL '1 month')::date        AS cohort_start,    -- первая полная когорта
	data_end,                                                                           -- последний день данных
	(DATE_TRUNC('month', data_end + 1) - INTERVAL '1 month')::date  AS data_end_month   -- последняя полная когорта
FROM b;

-- Проверка: сейчас ожидается 2021-08-01 | 2022-06-08 | 2022-05-01
SELECT * FROM etl.params;
