create view rfm_segments as (
	with scores as (
		select
			card,
			case
				when recency <= (
					select
						perc_25
					from
						rfm_segmentation_thresholds
					where
						metric_name = 'recency'
				) then 1
				when recency >= (
					select
						perc_75
					from
						rfm_segmentation_thresholds
					where
						metric_name = 'recency'
				) then 3
				else 2
			end as r_score,
			case
				when frequency <= (
					select
						perc_25
					from
						rfm_segmentation_thresholds
					where
						metric_name = 'frequency'
				) then 1
				when frequency >= (
					select
						perc_75
					from
						rfm_segmentation_thresholds
					where
						metric_name = 'frequency'
				) then 3
				else 2
			end as f_score,
			case
				when monetary <= (
					select
						perc_25
					from
						rfm_segmentation_thresholds
					where
						metric_name = 'monetary'
				) then 1
				when monetary >= (
					select
						perc_75
					from
						rfm_segmentation_thresholds
					where
						metric_name = 'monetary'
				) then 3
				else 2
			end as m_score
		from
			rfm_metrics
		order by
			card
	)
	select
		card,
		concat(r_score, f_score, m_score) as rfm_segment
	from
		scores
	order by
		rfm_segment
)