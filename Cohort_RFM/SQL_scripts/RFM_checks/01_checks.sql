-- Проверки RFM одним запросом: должна вернуть 0 строк; check_name показывает, какая проверка сработала.
-- Запускать после RFM_view (в ноутбуке: run_checks("RFM_checks")).

select 'thresholds: число строк не равно 3' as check_name, count(*)::text as detail
from mart.rfm_segmentation_thresholds
having count(*) <> 3

union all
select 'thresholds: дубль метрики', metric_name
from mart.rfm_segmentation_thresholds
group by metric_name
having count(*) > 1

union all
select 'клиенты: rfm_metrics <> etl.clients',
	(select count(*) from mart.rfm_metrics)::text || ' vs ' || (select count(*) from etl.clients)::text
where (select count(*) from mart.rfm_metrics) <> (select count(*) from etl.clients)

union all
select 'клиенты: rfm_segments <> rfm_metrics',
	(select count(*) from mart.rfm_segments)::text || ' vs ' || (select count(*) from mart.rfm_metrics)::text
where (select count(*) from mart.rfm_segments) <> (select count(*) from mart.rfm_metrics)

union all
select 'выручка: rfm_metrics <> etl.orders',
	(select sum(monetary) from mart.rfm_metrics)::text || ' vs ' || (select sum(total) from etl.orders)::text
where abs((select sum(monetary) from mart.rfm_metrics) - (select sum(total) from etl.orders)) > 0.01

union all
select 'код сегмента попал в несколько групп', rfm_segment
from mart.rfm_segments
group by rfm_segment
having count(distinct segment_group) > 1

union all
select 'доли не дают 100%', 'клиенты=' || u::text || ', выручка=' || m::text
from (select sum(users_share) as u, sum(monetary_share) as m from mart.rfm_segment_share) s
where abs(u - 100) > 0.5 or abs(m - 100) > 0.5


union all
select
	'объект RFM вне схемы mart (старая версия)',
	table_schema || '.' || table_name
from
	information_schema.tables
where
	table_name ilike '%rfm%'
	and table_schema not in (
		'mart', 'information_schema', 'pg_catalog'
	);
