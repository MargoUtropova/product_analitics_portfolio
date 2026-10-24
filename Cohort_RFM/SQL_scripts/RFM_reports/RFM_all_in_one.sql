with customer_transactions as (
	select
		card as customer_card,
		summ_with_disc as transaction_amount,
		COUNT(card) over (
			partition by card
		) as transaction_count,
		MAX(datetime::DATE) over () as analysis_reference_date,
		MAX(datetime::DATE) over (
			partition by card
		) as last_purchase_date
	from
		checks
	where
		card like '2000%'
		and summ_with_disc > 0
		and datetime >= '2000-01-01'
		and datetime <= NOW()
),
rfm_aggregated as (
	select
		customer_card,
		MIN(analysis_reference_date - last_purchase_date) as recency,
		MIN(transaction_count) as frequency,
		SUM(transaction_amount) as monetary
	from
		customer_transactions
	group by
		customer_card
),
percentiles as (
	select
		'Recency' as metric_name,
		PERCENTILE_DISC(0.33) within group (
		order by
			recency
		) as percentile_33,
		PERCENTILE_DISC(0.5) within group (
		order by
			recency
		) as median,
		PERCENTILE_DISC(0.66) within group (
		order by
			recency
		) as percentile_66
	from
		rfm_aggregated
union all
	select
		'Frequency',
		PERCENTILE_DISC(0.33) within group (
		order by
			frequency
		),
		PERCENTILE_DISC(0.5) within group (
		order by
			frequency
		),
		PERCENTILE_DISC(0.66) within group (
		order by
			frequency
		)
	from
		rfm_aggregated
union all
	select
		'Monetary',
		PERCENTILE_DISC(0.33) within group (
		order by
			monetary
		),
		PERCENTILE_DISC(0.5) within group (
		order by
			monetary
		),
		PERCENTILE_DISC(0.66) within group (
		order by
			monetary
		)
	from
		rfm_aggregated
),
rfm_segments_total as (
	select
		ra.customer_card,
		concat(case
            when recency <= (select percentile_33 from percentiles where metric_name = 'Recency') then 1
            when recency <= (select percentile_66 from percentiles where metric_name = 'Recency') then 2
            else 3
        end,
        case
            when frequency <= (select percentile_33 from percentiles where metric_name = 'Frequency') then 3
            when frequency <= (select percentile_66 from percentiles where metric_name = 'Frequency') then 2
            else 1
        end,
        case
            when monetary <= (select percentile_33 from percentiles where metric_name = 'Monetary') then 3
            when monetary <= (select percentile_66 from percentiles where metric_name = 'Monetary') then 2
            else 1
        end) as rfm_segment
	from
		rfm_aggregated ra
	order by
		customer_card
)
select
	rfm_segment as "RFM-Сегмент",
	COUNT(customer_card) as "Кол-во клиентов",
	ROUND(COUNT(customer_card) * 100.0 / SUM(COUNT(customer_card)) over (), 2) as "Доля"
from
	rfm_segments_total
group by
	rfm_segment
order by
	rfm_segment