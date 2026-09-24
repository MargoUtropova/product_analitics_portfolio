with cohorts as
(
	with cte as (
		select
			datetime::date,
			first_value(datetime::date) over (
				partition by card
			order by
				datetime
			) as first_purchase,
			card,
			summ_with_disc
		from
			checks
		where
			card like '2000%'
			and summ > 0
			and datetime::date between '2000-01-01' and now()
	)
	select
		datetime,
		first_purchase,
		summ_with_disc,
		card,
		datetime::date - first_purchase::date as date_diff,
		date_trunc('month', first_purchase)::date as cohort
	from
		cte
)
select
	cohort,
	round(SUM(case when date_diff = 0 then summ_with_disc end)/ count(distinct card)) as "0_day",
	case
		when MAX(date_diff) >= 30 then round(SUM(case when date_diff <= 30 then summ_with_disc end)/ count(distinct card))
		else 0
	end as "30_day",
	case
		when MAX(date_diff) >= 60 then round(SUM(case when date_diff <= 60 then summ_with_disc end) / count(distinct card))
		else 0
	end as "60_day",
	case
		when MAX(date_diff) >= 90 then round(SUM(case when date_diff <= 90 then summ_with_disc end) / count(distinct card))
		else 0
	end as "90_day",
	case
		when MAX(date_diff) >= 120 then round(SUM(case when date_diff <= 120 then summ_with_disc end) / count(distinct card))
		else 0
	end as "120_day",
	case
		when MAX(date_diff) >= 150 then round(SUM(case when date_diff <= 150 then summ_with_disc end) / count(distinct card))
		else 0
	end as "150_day",
	case
		when MAX(date_diff) >= 180 then round(SUM(case when date_diff <= 180 then summ_with_disc end) / count(distinct card))
		else 0
	end as "180_day"
from
	cohorts
WHERE cohort NOT IN ('2021-07-01', '2022-06-01') --убрали неполные месяца
group by
	cohort