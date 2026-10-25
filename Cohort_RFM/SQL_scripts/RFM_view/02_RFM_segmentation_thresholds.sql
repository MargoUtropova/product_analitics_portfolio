-- Пороги сегментации (33-й и 66-й перцентили) считаются на mart.rfm_metrics.
-- truncate: при повторном запуске строки не дублируются (иначе подзапросы в mart.rfm_segments вернут несколько строк).
create table if not exists mart.rfm_segmentation_thresholds (
	metric_name text,
	percentile_33 double precision,
	percentile_66 double precision
);

truncate mart.rfm_segmentation_thresholds;

insert into mart.rfm_segmentation_thresholds
select 'Recency',
	percentile_cont(1 / 3.0) within group (order by recency),
	percentile_cont(2 / 3.0) within group (order by recency)
from mart.rfm_metrics
union all
select 'Frequency',
	percentile_cont(1 / 3.0) within group (order by frequency),
	percentile_cont(2 / 3.0) within group (order by frequency)
from mart.rfm_metrics
union all
select 'Monetary',
	percentile_cont(1 / 3.0) within group (order by monetary),
	percentile_cont(2 / 3.0) within group (order by monetary)
from mart.rfm_metrics;
