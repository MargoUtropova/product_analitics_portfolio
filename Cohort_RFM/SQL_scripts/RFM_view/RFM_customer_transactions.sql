WITH customer_transactions AS (
    SELECT
        card AS customer_card,
        summ_with_disc AS transaction_amount,
        COUNT(card) OVER (PARTITION BY card) AS transaction_count,
        MAX(datetime::DATE) OVER () AS analysis_reference_date,
        MAX(datetime::DATE) OVER (PARTITION BY card) AS last_purchase_date
    FROM checks
    WHERE card LIKE '2000%'
      AND summ_with_disc > 0
      AND datetime >= '2000-01-01'
      AND datetime <= NOW()
), rfm_aggregated as (
SELECT
    customer_card,
    MIN(analysis_reference_date - last_purchase_date) AS recency_days,
    MIN(transaction_count) AS frequency_count,
    SUM(transaction_amount) AS monetary_total
FROM customer_transactions
GROUP BY customer_card
), percentiles as (
SELECT
    'Recency' AS metric_name,
    PERCENTILE_DISC(0.33) WITHIN GROUP (ORDER BY recency_days) AS percentile_33,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY recency_days) AS median,
    PERCENTILE_DISC(0.66) WITHIN GROUP (ORDER BY recency_days) AS percentile_66
FROM rfm_aggregated
UNION ALL
SELECT
    'Frequency',
    PERCENTILE_DISC(0.33) WITHIN GROUP (ORDER BY frequency_count),
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY frequency_count),
    PERCENTILE_DISC(0.66) WITHIN GROUP (ORDER BY frequency_count)
FROM rfm_aggregated
UNION ALL
SELECT
    'Monetary',
    PERCENTILE_DISC(0.33) WITHIN GROUP (ORDER BY monetary_total),
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY monetary_total),
    PERCENTILE_DISC(0.66) WITHIN GROUP (ORDER BY monetary_total)
FROM rfm_aggregated
), rfm_segments_total as (
    SELECT
        ra.customer_card,
        concat(CASE
            WHEN recency_days <= (SELECT percentile_33 FROM percentiles WHERE metric_name = 'Recency') THEN 1
            WHEN recency_days <= (SELECT percentile_66 FROM percentiles WHERE metric_name = 'Recency') THEN 2
            ELSE 3
        END,
        CASE
            WHEN frequency_count <= (SELECT percentile_33 FROM percentiles WHERE metric_name = 'Frequency') THEN 3
            WHEN frequency_count <= (SELECT percentile_66 FROM percentiles WHERE metric_name = 'Frequency') THEN 2
            ELSE 1
        END,
        CASE
            WHEN monetary_total <= (SELECT percentile_33 FROM percentiles WHERE metric_name = 'Monetary') THEN 3
            WHEN monetary_total <= (SELECT percentile_66 FROM percentiles WHERE metric_name = 'Monetary') THEN 2
            ELSE 1
        END) as rfm_segment
    FROM rfm_aggregated ra
    ORDER BY customer_card
)
SELECT
    rfm_segment AS "RFM-Сегмент",
    COUNT(customer_card) AS "Кол-во клиентов",
    TO_CHAR(ROUND(COUNT(customer_card) * 100.0 / SUM(COUNT(customer_card)) OVER (), 2), 'fm00D00%') AS "Доля"
FROM rfm_segments_total
GROUP BY rfm_segment
ORDER BY rfm_segment