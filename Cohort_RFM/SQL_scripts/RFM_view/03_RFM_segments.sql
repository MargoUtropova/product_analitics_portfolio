create or replace
view mart.rfm_segments as (
	with customer_segmentation as (
		select
			card,
			case
				when recency <= (
					select
						percentile_33
					from
						mart.rfm_segmentation_thresholds
					where
						metric_name = 'Recency'
				) then 1
				when recency <= (
					select
						percentile_66
					from
						mart.rfm_segmentation_thresholds
					where
						metric_name = 'Recency'
				) then 2
				else 3
			end as r_score,
			case
				when frequency <= (
					select
						percentile_33
					from
						mart.rfm_segmentation_thresholds
					where
						metric_name = 'Frequency'
				) then 3
				when frequency <= (
					select
						percentile_66
					from
						mart.rfm_segmentation_thresholds
					where
						metric_name = 'Frequency'
				) then 2
				else 1
			end as f_score,
			case
				when monetary <= (
					select
						percentile_33
					from
						mart.rfm_segmentation_thresholds
					where
						metric_name = 'Monetary'
				) then 3
				when monetary <= (
					select
						percentile_66
					from
						rfm_segmentation_thresholds
					where
						metric_name = 'Monetary'
				) then 2
				else 1
			end as m_score
		from
			mart.rfm_metrics rcm
		order by
			card
	)
	select
		card,
		CONCAT(r_score, f_score, m_score) as rfm_segment,
		case
			when r_score = 1
			and f_score = 1
			and m_score = 1 then '1 Чемпионы'
			when r_score = 1
			and f_score <= 2 then '2 Активные лояльные'
			when r_score = 1 then '3 Новые и разовые'
			when r_score = 2
			and f_score <= 2
			and m_score <= 2 then '4 Остывающие ценные'
			when r_score = 2 then '5 Остывающие прочие'
			when r_score = 3
			and f_score <= 2
			and m_score <= 2 then '6 Уходящие ценные'
			else '7 Потерянные'
		end as segment_group
	from
		customer_segmentation
	order by
		rfm_segment
)