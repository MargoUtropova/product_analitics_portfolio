-- Распределение выручки на покупателя в окне 1-30 дней по когортам (когорты август 2021 — апрель 2022: окно полное).
-- Если отношение mean / median примерно одинаково у всех когорт, перекос свойство распределения, а не выброс отдельной когорты.
-- top5_share_pct: доля выручки пяти самых крупных покупателей когорты в этом окне.
with t as (
	select c.cohort_month, c.card, sum(o.total) as revenue
	from etl.clients c
	join etl.orders o on o.card = c.card
	where o.order_date - c.anchor_date between 1 and 30
		and c.cohort_month between '2021-08-01' and '2022-04-01'
	group by c.cohort_month, c.card
),
r as (
	select *, row_number() over (partition by cohort_month order by revenue desc) as rn
	from t
)
select
	cohort_month,
	count(*)                                                                 as buyers,
	round(avg(revenue))                                                      as mean,
	round(percentile_cont(0.5) within group (order by revenue)::numeric)    as median,
	round((avg(revenue) / percentile_cont(0.5) within group (order by revenue))::numeric, 2) as mean_to_median,
	round(100.0 * sum(revenue) filter (where rn <= 5) / sum(revenue), 1)    as top5_share_pct
from r
group by cohort_month
order by cohort_month;