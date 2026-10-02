create or replace view rfm_segmentation_thresholds as (
	select
		'recency' as metric_name,
		PERCENTILE_DISC(0.33) within group (
		order by
			recency
		) as perc_33,
		PERCENTILE_DISC(0.5) within group (
		order by
			recency
		) as median,
		PERCENTILE_DISC(0.66) within group (
		order by
			recency
		) as perc_66
	from
		rfm_metrics
union all
	select
		'frequency' as metric_name,
		PERCENTILE_DISC(0.33) within group (
		order by
			frequency
		) as perc_33,
		PERCENTILE_DISC(0.5) within group (
		order by
			frequency
		) as median,
		PERCENTILE_DISC(0.66) within group (
		order by
			frequency
		) as perc_66
	from
		rfm_metrics
union all
	select
		'monetary' as metric_name,
		PERCENTILE_DISC(0.33) within group (
		order by
			monetary
		) as perc_33,
		PERCENTILE_DISC(0.5) within group (
		order by
			monetary
		) as median,
		PERCENTILE_DISC(0.66) within group (
		order by
			monetary
		) as perc_66
	from
		rfm_metrics
)
