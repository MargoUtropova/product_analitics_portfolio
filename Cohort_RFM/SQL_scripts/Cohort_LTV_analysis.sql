with cohorts as --выделяем когорты как первый день каждого месяца
(
	with cte as (
		select
		-- определяем покупку нулевого дня
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
		-- фильтр по дате и по корректности операции
			card like '2000%'
			and summ > 0
			and datetime::date between '2000-01-01' and now()
	)
	select
		datetime, -- дата покупки
		first_purchase, -- дата нулевой покупки
		summ_with_disc, -- "чистая" сумма
		card, -- id клиента
		datetime::date - first_purchase::date as date_diff, -- разница в днях между первой и текущей покупкой
		date_trunc('month', first_purchase)::date as cohort -- первое число месяца первой покупки для отнесения к когортам
	from
		cte
)
select
	cohort,
	--  Расчёт среднего LTV на клиента на каждом отрезке времени, иначе 0
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
group by
	cohort