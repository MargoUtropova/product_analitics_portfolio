create view rfm_metrics as (
	with dates as (
		select
			datetime::date,
			summ_with_disc,
			count(*) over(partition by card) as frequency,
			max(datetime::date) over(partition by card) as last_purchase,
			MAX(datetime::date) over() as last_date,
			MAX(datetime::date) over() - max(datetime::date) over(partition by card) as recency,
			card
		from
			checks
		where
			card like '2000%'
			and summ_with_disc > 0
			and datetime::date between '2000-01-01' and now()
	)
	select
		card,
		min(recency) as recency,
		max(frequency) as frequency,
		sum(summ_with_disc) as monetary
	from
		dates
	group by
		card
)
