create view rfm_segmentation_thresholds as (
select 'Recency' as metric_name,
PERCENTILE_DISC(0.33) within group (order by recency_days) as percentile_33,
percentile_disc(0.5) within group (order by recency_days) as median,
percentile_disc(0.66) within group (order by recency_days) as percentile_66
from rfm_customer_metrics rcm
union all
select 'Frequency' as metric_name,
PERCENTILE_DISC(0.33) within group (order by frequency_count) as percentile_33,
percentile_disc(0.5) within group (order by frequency_count) as median,
percentile_disc(0.66) within group (order by frequency_count) as percentile_66
from rfm_customer_metrics rcm
union all
select 'Monetary' as metric_name,
PERCENTILE_DISC(0.33) within group (order by monetary_total) as percentile_33,
percentile_disc(0.5) within group (order by monetary_total) as median,
percentile_disc(0.66) within group (order by monetary_total) as percentile_66
from rfm_customer_metrics rcm
)