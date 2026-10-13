with cohorts as (
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
),
agg as (
	select
		date_trunc('month', first_purchase)::date as cohort,
		datetime::date - first_purchase::date as date_diff,
		card,
		summ_with_disc,
		first_purchase
	from
		cohorts
)
select
	a.cohort,
	ROUND(SUM(case when a.date_diff = 0 then a.summ_with_disc end)
        / nullif(count(distinct a.card), 0)) as "0_day",
	case
		when MAX(a.first_purchase) + 30 <= p.data_end
       then ROUND(SUM(case when a.date_diff <= 30 then a.summ_with_disc end)
                  / nullif(count(distinct a.card), 0))
	end as "30_day",
	case
		when MAX(a.first_purchase) + 60 <= p.data_end
       then ROUND(SUM(case when a.date_diff <= 60 then a.summ_with_disc end)
                  / nullif(count(distinct a.card), 0))
	end as "60_day",
	case
		when MAX(a.first_purchase) + 90 <= p.data_end
       then ROUND(SUM(case when a.date_diff <= 90 then a.summ_with_disc end)
                  / nullif(count(distinct a.card), 0))
	end as "90_day",
	case
		when MAX(a.first_purchase) + 120 <= p.data_end
       then ROUND(SUM(case when a.date_diff <= 120 then a.summ_with_disc end)
                  / nullif(count(distinct a.card), 0))
	end as "120_day",
	case
		when MAX(a.first_purchase) + 150 <= p.data_end
       then ROUND(SUM(case when a.date_diff <= 150 then a.summ_with_disc end)
                  / nullif(count(distinct a.card), 0))
	end as "150_day",
	case
		when MAX(a.first_purchase) + 180 <= p.data_end
       then ROUND(SUM(case when a.date_diff <= 180 then a.summ_with_disc end)
                  / nullif(count(distinct a.card), 0))
	end as "180_day"
from
	agg a
cross join etl.params p
where
	a.cohort >= p.cohort_start
	-- отсекаем первый неполный месяц
	and a.cohort not in (
		'2021-07-01', '2022-06-01'
	)
	-- если ещё нужны ручные исключения
group by
	a.cohort,
	p.data_end
order by
	a.cohort;