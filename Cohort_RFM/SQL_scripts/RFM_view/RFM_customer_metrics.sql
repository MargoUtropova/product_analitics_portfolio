create or replace view rfm_customer_metrics as (
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
	)
	select
		customer_card,
		MIN(analysis_reference_date - last_purchase_date) as recency_days,
		MIN(transaction_count) as frequency_count,
		SUM(transaction_amount) as monetary_total
	from
		customer_transactions
	group by
		customer_card
)