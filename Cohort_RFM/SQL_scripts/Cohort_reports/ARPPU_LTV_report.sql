-- Все метрики когорт в одной таблице (когорта × окно). Для Power BI: фильтруйте по is_complete.
select
	cohort_month as cohort,
	cohort_size,
	window_no,
	period,
	day_k,
	eligible_users,
	active_users,
	retention,
	arpu,
	arppu,
	ltv,
	revenue_window,
	revenue_cum,
	is_complete
from mart.cohort_metrics
order by cohort_month, window_no;
