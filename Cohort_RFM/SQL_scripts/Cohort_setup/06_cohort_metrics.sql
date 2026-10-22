-- 06_cohort_metrics.sql: единые метрики когорт (LTV, ARPU, ARPPU, retention) на базе mart.client_ltv
-- Активность в окне = прирост накопленной выручки клиента за окно > 0. Все метрики считаются на одной базе клиентов:
--   ARPU окна = retention × ARPPU;  LTV(k) = LTV(k-30 на той же базе) + ARPU окна k.
-- window_no = 0 — день первой покупки; 1..6 — окна 1-30, ..., 151-180.
-- is_complete — окно полностью наблюдалось у всей когорты (то же правило, что is_mature в mart.retention_cohorts).

create or replace view mart.cohort_metrics as
with sizes as (
	select c.cohort_month, count(*) as cohort_size
	from mart.client_ltv c
	cross join etl.params p
	where c.cohort_month <= p.data_end_month
	group by c.cohort_month
),
pts as (                                                     -- клиент × окно, только если окно уже закончилось
	select c.cohort_month, v.w, v.k, v.ltv_k, v.ltv_prev
	from mart.client_ltv c
	cross join etl.params p
	cross join lateral (
		values
			(0,   0, c.ltv_0::numeric,   null::numeric),
			(1,  30, c.ltv_30::numeric,  c.ltv_0::numeric),
			(2,  60, c.ltv_60::numeric,  c.ltv_30::numeric),
			(3,  90, c.ltv_90::numeric,  c.ltv_60::numeric),
			(4, 120, c.ltv_120::numeric, c.ltv_90::numeric),
			(5, 150, c.ltv_150::numeric, c.ltv_120::numeric),
			(6, 180, c.ltv_180::numeric, c.ltv_150::numeric)
	) as v(w, k, ltv_k, ltv_prev)
	where c.cohort_month <= p.data_end_month
		and v.ltv_k is not null
)
select
	pts.cohort_month,
	s.cohort_size,
	pts.w                                                    as window_no,
	pts.k                                                    as day_k,
	case when pts.w = 0 then 'day 0' else (pts.k - 29) || '-' || pts.k end as period,
	count(*)                                                 as eligible_users,
	count(*) filter (where pts.w = 0 or pts.ltv_k - pts.ltv_prev > 0.005)            as active_users,
	round(((count(*) filter (where pts.w = 0 or pts.ltv_k - pts.ltv_prev > 0.005))::numeric / count(*)), 4) as retention,
	round((sum(pts.ltv_k - coalesce(pts.ltv_prev, 0)) / count(*))::numeric, 2)       as arpu,
	round((sum(pts.ltv_k - coalesce(pts.ltv_prev, 0))
		/ nullif(count(*) filter (where pts.w = 0 or pts.ltv_k - pts.ltv_prev > 0.005), 0))::numeric, 2) as arppu,
	round(avg(pts.ltv_k)::numeric, 2)                                                as ltv,
	round(avg(coalesce(pts.ltv_prev, 0))::numeric, 2)                                as ltv_prev_same_base,
	sum(pts.ltv_k - coalesce(pts.ltv_prev, 0))                                       as revenue_window,
	sum(pts.ltv_k)                                                                   as revenue_cum,
	(pts.cohort_month + interval '1 month' + pts.k * interval '1 day' <= p.data_end + 1) as is_complete
from pts
join sizes s on s.cohort_month = pts.cohort_month
cross join etl.params p
group by pts.cohort_month, s.cohort_size, pts.w, pts.k, p.data_end;
