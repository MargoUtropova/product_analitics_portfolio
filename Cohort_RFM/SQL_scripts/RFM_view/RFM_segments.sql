CREATE VIEW view_rfm_segments AS (
WITH customer_segmentation AS (
select customer_card,
case
	when recency_days <= (select percentile_33 from rfm_segmentation_thresholds where metric_name = 'Recency') then 1
	when recency_days <= (select percentile_66 from rfm_segmentation_thresholds where metric_name = 'Recency') then 2
	else 3
end as r_score,
case
	when frequency_count <= (select percentile_33 from rfm_segmentation_thresholds where metric_name = 'Frequency') then 3
	when frequency_count <= (select percentile_66 from rfm_segmentation_thresholds where metric_name = 'Frequency') then 2
	else 1
end as f_score,
case
	when monetary_total <= (select percentile_33 from rfm_segmentation_thresholds where metric_name = 'Monetary') then 3
	when monetary_total <= (select percentile_66 from rfm_segmentation_thresholds where metric_name = 'Monetary') then 2
	else 1
end as m_score
from rfm_customer_metrics rcm
order by customer_card
)
SELECT
    customer_card,
    CONCAT(r_score, f_score, m_score) AS rfm_segment
FROM customer_segmentation
ORDER BY rfm_segment
)