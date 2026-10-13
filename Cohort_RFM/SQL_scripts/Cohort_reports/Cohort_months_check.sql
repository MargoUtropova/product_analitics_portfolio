-- вычисляем, сколько дней в каждом месяце, чтобы отбросить неполные в итоговом запросе
select
	DATE_TRUNC('month', datetime)::DATE as cohort_month,
	MIN(datetime)::DATE as first_date,
	MAX(datetime)::DATE as last_date,
	(
		MAX(datetime)::DATE - MIN(datetime)::DATE
	) + 1 as days_in_month
from
	checks
where
	card like '2000%'
	and summ_with_disc > 0
	and datetime >= '2000-01-01'
	and datetime <= NOW()
group by
	DATE_TRUNC('month', datetime)::DATE
order by
	cohort_month