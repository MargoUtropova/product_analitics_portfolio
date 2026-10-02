CREATE VIEW rfm_customer_metrics AS (
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
)
SELECT
    customer_card,
    MIN(analysis_reference_date - last_purchase_date) AS recency_days,
    MIN(transaction_count) AS frequency_count,
    SUM(transaction_amount) AS monetary_total
FROM customer_transactions
GROUP BY customer_card
)