with cohort_cte as (
-- разделяем на когорты по первому числу месяца даты первой покупки для каждого пользователя
	select
		card,
		datetime::date,
		datetime::date - first_value(datetime::date) over(partition by card order by datetime) as date_diff,
		date_trunc('month', first_value(datetime::date) over(partition by card order by datetime))::date as cohort,
		summ_with_disc
	from
		checks
	where
		card like '2000%'
		and datetime::date between '2021-01-01' and now()
	order by
		card
)
select
	cohort,
	-- вычисляем ARPU по каждому клиенту в рамках периода в 30 дней, не накопительно
	count(distinct card) as users_count, -- кол-во уник-х польз-лей внутри когорты
	--- считаем, сколько уникальных пользователей сделали транзакции внутри периода
	count(distinct case when date_diff between 1 and 30 then card end) as "1-30_users",
	count(distinct case when date_diff between 31 and 60 then card end) as "31-60_users",
	count(distinct case when date_diff between 61 and 90 then card end) as "61-90_users",
	count(distinct case when date_diff between 91 and 120 then card end) as "91-120_users",
	count(distinct case when date_diff between 121 and 150 then card end) as "121-150_users",
	count(distinct case when date_diff between 151 and 180 then card end) as "151-180_users",
	-- далее для сравнения чередуются ARPU на всех пользователей за период и ARPPU,
	-- т.е делим на кол-во только тех польз-й, кто совершил покупку
	round(sum(case when date_diff = 0 then summ_with_disc end)/ count(distinct card), 2) as first_purchase,
	round(sum(case when date_diff between 1 and 30 then summ_with_disc end)/ count(distinct card), 2) as "1-30_day",
	round(sum(case when date_diff between 1 and 30 then summ_with_disc end)/ count(distinct case when date_diff between 1 and 30 then card end), 2) as "1-30_ARPPU",
	round(sum(case when date_diff between 31 and 60 then summ_with_disc end)/ count(distinct card), 2) as "31-60_day",
	round(sum(case when date_diff between 31 and 60 then summ_with_disc end)/ count(distinct case when date_diff between 31 and 60 then card end), 2) as "31-60_ARPPU",
	round(sum(case when date_diff between 61 and 90 then summ_with_disc end)/ count(distinct card), 2) as "61-90_day",
	round(sum(case when date_diff between 61 and 90 then summ_with_disc end)/ count(distinct case when date_diff between 61 and 90 then card end), 2) as "61-90_60_ARPPU",
	round(sum(case when date_diff between 91 and 120 then summ_with_disc end)/ count(distinct card), 2) as "91-120_day",
	round(sum(case when date_diff between 91 and 120 then summ_with_disc end)/ count(distinct case when date_diff between 91 and 120 then card end), 2) as "91-120_ARPPU",
	round(sum(case when date_diff between 121 and 150 then summ_with_disc end)/ count(distinct card), 2) as "121-150_day",
	round(sum(case when date_diff between 121 and 150 then summ_with_disc end)/ count(distinct case when date_diff between 121 and 150 then card end), 2) as "121-150_ARPPU",
	round(sum(case when date_diff between 151 and 180 then summ_with_disc end)/ count(distinct card), 2) as "151-180_day",
	round(sum(case when date_diff between 151 and 180 then summ_with_disc end)/ count(distinct case when date_diff between 151 and 180 then card end), 2) as "151-180_ARPPU"
from
	cohort_cte
where
	cohort not in (
		'2022-06-01', '2021-07-01' -- исключаем неполные месяцы
	)
group by
	cohort
order by
	cohort
