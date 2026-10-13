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
		MIN(analysis_reference_date - last_purchase_date) as recency_days,
		MIN(transaction_count) as frequency_count,
		SUM(transaction_amount) as monetary_total
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
			recency_days
		) as percentile_33,
		PERCENTILE_DISC(0.5) within group (
		order by
			recency_days
		) as median,
		PERCENTILE_DISC(0.66) within group (
		order by
			recency_days
		) as percentile_66
	from
		rfm_aggregated
union all
	select
		'Frequency',
		PERCENTILE_DISC(0.33) within group (
		order by
			frequency_count
		),
		PERCENTILE_DISC(0.5) within group (
		order by
			frequency_count
		),
		PERCENTILE_DISC(0.66) within group (
		order by
			frequency_count
		)
	from
		rfm_aggregated
union all
	select
		'Monetary',
		PERCENTILE_DISC(0.33) within group (
		order by
			monetary_total
		),
		PERCENTILE_DISC(0.5) within group (
		order by
			monetary_total
		),
		PERCENTILE_DISC(0.66) within group (
		order by
			monetary_total
		)
	from
		rfm_aggregated
),
rfm_segments_total as (
	select
		ra.customer_card,
		concat(case
            when recency_days <= (select percentile_33 from percentiles where metric_name = 'Recency') then 1
            when recency_days <= (select percentile_66 from percentiles where metric_name = 'Recency') then 2
            else 3
        end,
        case
            when frequency_count <= (select percentile_33 from percentiles where metric_name = 'Frequency') then 3
            when frequency_count <= (select percentile_66 from percentiles where metric_name = 'Frequency') then 2
            else 1
        end,
        case
            when monetary_total <= (select percentile_33 from percentiles where metric_name = 'Monetary') then 3
            when monetary_total <= (select percentile_66 from percentiles where metric_name = 'Monetary') then 2
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
	TO_CHAR(ROUND(COUNT(customer_card) * 100.0 / SUM(COUNT(customer_card)) over (), 2), 'fm00D00%') as "Доля"
from
	rfm_segments_total
group by
	rfm_segment
order by
	rfm_segment