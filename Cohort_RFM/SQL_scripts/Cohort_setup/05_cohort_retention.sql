-- 05_cohort_retention.sql: retention по когортам (факт для зрелых окон, прогноз для незрелых)
CREATE SCHEMA IF NOT EXISTS mart;

DROP TABLE IF EXISTS mart.retention_cohorts CASCADE;

CREATE TABLE mart.retention_cohorts AS

WITH first_purchase as (
          select card, first_purchase, cohort_month as cohort
          from etl.clients
      ),

data_cutoff as (
          select data_end + 1 as max_date          -- день отсечки + 1: то же правило зрелости, что is_complete в mart.cohort_metrics
          from etl.params
      ),
cohort_calendar as (
          select generate_series(p.cohort_start, p.data_end_month, interval '1 month')::date as cohort
          from etl.params p
      ),

cohort_sizes AS (
    SELECT
        cc.cohort,
        COUNT(fp.card) AS cohort_size
    FROM cohort_calendar cc
    LEFT JOIN first_purchase fp
        ON fp.cohort = cc.cohort
    GROUP BY cc.cohort
),

periods AS (
    SELECT *
    FROM (VALUES
        ('1-30', 1, 30),
        ('31-60', 31, 60),
        ('61-90', 61, 90),
        ('91-120', 91, 120),
        ('121-150', 121, 150),
        ('151-180', 151, 180)
    ) AS p(period, day_from, day_to)
),

-- user_activity: активность по заказам etl.orders
      user_activity as (
          select fp.cohort, p.period, count(distinct fp.card) as users
          from first_purchase fp
          join etl.orders c on c.card = fp.card
          join periods p on c.order_date - fp.first_purchase between p.day_from and p.day_to
          where fp.cohort between (select cohort_start from etl.params) and (select data_end_month from etl.params)
          group by fp.cohort, p.period
      ),
cohort_periods AS (
    -- Каждая когорта × каждый период, включая периоды без покупок
    SELECT
        cs.cohort,
        cs.cohort_size,
        p.period,
        p.day_to,
        dc.max_date,
        COALESCE(ua.users, 0) AS observed_users,

        -- Полностью ли наблюдался интервал для всей когорты?
        (
            cs.cohort + INTERVAL '1 month'
            + p.day_to * INTERVAL '1 day'
            <= dc.max_date
        ) AS is_mature

    FROM cohort_sizes cs
    CROSS JOIN periods p
    CROSS JOIN data_cutoff dc
    LEFT JOIN user_activity ua
        ON ua.cohort = cs.cohort
       AND ua.period = p.period
),

benchmarks AS (
    -- Общий фактический Retention зрелых когорт
    SELECT
        period,
        SUM(observed_users)::numeric
        / NULLIF(SUM(cohort_size), 0) AS benchmark_retention
    FROM cohort_periods
    WHERE is_mature
    GROUP BY period
)

SELECT
    cp.cohort,
    cp.cohort_size,
    cp.period,
    cp.is_mature,

    -- Фактические данные доступны только
    -- для полностью наблюдавшихся интервалов
    CASE
        WHEN cp.is_mature THEN cp.observed_users
        ELSE NULL
    END AS actual_users,

    CASE
        WHEN cp.is_mature
        THEN ROUND(
            100.0 * cp.observed_users
            / NULLIF(cp.cohort_size, 0),
            2
        )
        ELSE NULL
    END AS retention_actual,

    -- Для незрелых периодов используем
    -- взвешенный Retention зрелых когорт
    CASE
        WHEN NOT cp.is_mature
        THEN ROUND(
            100.0 * b.benchmark_retention,
            2
        )
        ELSE NULL
    END AS retention_forecast,

    CASE
        WHEN NOT cp.is_mature
        THEN ROUND(
            cp.cohort_size * b.benchmark_retention
        )
        ELSE NULL
    END AS forecast_users


from cohort_periods cp
left join benchmarks b
    on
b.period = cp.period
order by
cp.cohort,
cp.day_to;
