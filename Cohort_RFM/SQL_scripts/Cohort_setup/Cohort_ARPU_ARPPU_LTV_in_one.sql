-- =====================================================================
-- Запрос строит когортную таблицу: сначала определяет размер каждой когорты по месяцу входа,
-- затем для каждой когорты и каждого месяца её жизни считает выручку и число платящих,
-- после чего рассчитывает ARPU, ARPPU и накопительный LTV (накопительная выручка на клиента когорты).
-- Результат — таблица вида «когорта × месяц жизни» с ключевыми метриками монетизации.
-- =====================================================================
create view mart.cohort_ARPPU_ARPU_LTV as (
WITH cohort_sizes AS (
    -- Размер каждой исходной когорты
    SELECT
        cohort_month,
        COUNT(DISTINCT card) AS cohort_size
    FROM etl.clients
    GROUP BY cohort_month
),

monthly_activity AS (
    -- Выручка и платящие клиенты по месяцам жизни когорты
    SELECT
        c.cohort_month,
        (
            EXTRACT(YEAR FROM DATE_TRUNC('month', o.order_date))
            - EXTRACT(YEAR FROM c.cohort_month)
        ) * 12
        + EXTRACT(MONTH FROM DATE_TRUNC('month', o.order_date))
        - EXTRACT(MONTH FROM c.cohort_month)
            AS month_number,
        SUM(o.total) AS revenue,
        COUNT(DISTINCT o.card) AS paying_users
    FROM etl.orders o
    JOIN etl.clients c
        ON o.card = c.card
    GROUP BY
        c.cohort_month,
        month_number
),

cohort_metrics AS (
    SELECT
        ma.cohort_month,
        ma.month_number,
        cs.cohort_size,
        ma.revenue,
        ma.paying_users,

        -- ARPU за месяц
        ma.revenue / NULLIF(cs.cohort_size, 0)
            AS arpu,

        -- ARPPU за месяц
        ma.revenue / NULLIF(ma.paying_users, 0)
            AS arppu,

        -- Накопительная выручка с начала жизни когорты
        SUM(ma.revenue) OVER (
            PARTITION BY ma.cohort_month
            ORDER BY ma.month_number
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue
    FROM monthly_activity ma
    JOIN cohort_sizes cs
        ON ma.cohort_month = cs.cohort_month
    where ma.cohort_month <> '2021-07-01' and ma.cohort_month <> '2022-06-01' -- убираем неполные месяца
)

SELECT
    cohort_month,
    month_number,
    cohort_size,
    revenue,
    paying_users,
    ROUND(arpu::numeric, 2) AS arpu,
    ROUND(arppu::numeric, 2) AS arppu,
    ROUND(
        (cumulative_revenue / NULLIF(cohort_size, 0))::numeric,
        2
    ) AS ltv
FROM cohort_metrics
ORDER BY cohort_month, month_number
);
