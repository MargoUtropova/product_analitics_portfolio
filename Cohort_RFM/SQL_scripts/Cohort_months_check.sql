-- вычисляем, сколько дней в каждом месяце, чтобы отбросить неполные в итоговом запросе

SELECT
    DATE_TRUNC('month', datetime)::DATE AS cohort_month,
    MIN(datetime)::DATE AS first_date,
    MAX(datetime)::DATE AS last_date,
    (MAX(datetime)::DATE - MIN(datetime)::DATE) + 1 AS days_in_month
FROM checks
WHERE card LIKE '2000%'
  AND summ_with_disc > 0
  AND datetime >= '2000-01-01'
  AND datetime <= NOW()
GROUP BY DATE_TRUNC('month', datetime)::DATE
ORDER BY cohort_month