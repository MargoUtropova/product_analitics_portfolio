-- 04_client_ltv.sql: накопленная выручка клиента на днях 0, 30, ..., 180 (NULL, если точка ещё не наступила)
drop table if exists mart.client_ltv cascade;

create table mart.client_ltv as
select
	d.card,
	d.cohort_month,
	d.anchor_date,
	case
		when d.anchor_date + 0 <= p.data_end then coalesce(SUM(o.total) filter (where o.order_date <= d.anchor_date + 0), 0)
	end as ltv_0,
	case
		when d.anchor_date + 30 <= p.data_end then coalesce(SUM(o.total) filter (where o.order_date <= d.anchor_date + 30), 0)
	end as ltv_30,
	case
		when d.anchor_date + 60 <= p.data_end then coalesce(SUM(o.total) filter (where o.order_date <= d.anchor_date + 60), 0)
	end as ltv_60,
	case
		when d.anchor_date + 90 <= p.data_end then coalesce(SUM(o.total) filter (where o.order_date <= d.anchor_date + 90), 0)
	end as ltv_90,
	case
		when d.anchor_date + 120 <= p.data_end then coalesce(SUM(o.total) filter (where o.order_date <= d.anchor_date + 120), 0)
	end as ltv_120,
	case
		when d.anchor_date + 150 <= p.data_end then coalesce(SUM(o.total) filter (where o.order_date <= d.anchor_date + 150), 0)
	end as ltv_150,
	case
		when d.anchor_date + 180 <= p.data_end then coalesce(SUM(o.total) filter (where o.order_date <= d.anchor_date + 180), 0)
	end as ltv_180
from
	etl.clients d
cross join etl.params p
left join etl.orders o on
	o.card = d.card
where
	d.anchor_date >= p.cohort_start
	and d.cohort_month <= p.data_end_month
group by
	d.card,
	d.cohort_month,
	d.anchor_date,
	p.data_end;
