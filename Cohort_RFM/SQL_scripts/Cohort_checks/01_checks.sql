-- Все проверки одним запросом. Должна вернуть 0 строк; колонка check_name показывает, какая проверка сработала.
-- Если прогноз retention не используется и mart.retention_cohorts удалена, уберите два последних блока (cohort sizes, retention mismatch).
with expected as (                                   -- календарь когорт из параметров
	select generate_series(cohort_start, data_end_month, interval '1 month')::date as cohort_month
	from etl.params
),
actual as (
	select distinct cohort_month from mart.cohort_metrics
),
scope_clients as (                                   -- клиенты в границах когорт
	select count(*) as n
	from etl.clients c
	cross join etl.params p
	where c.anchor_date >= p.cohort_start
		and c.cohort_month <= p.data_end_month
)

-- 1. Параметры
select 'params' as check_name,
	'cohort_start=' || coalesce(cohort_start::text, 'null')
		|| ', data_end=' || coalesce(data_end::text, 'null')
		|| ', data_end_month=' || coalesce(data_end_month::text, 'null') as detail
from etl.params
where cohort_start is null
	or data_end is null
	or data_end_month is null
	or data_end_month < cohort_start
	or (data_end_month + interval '1 month')::date > data_end + 1      -- последняя когорта должна быть полным месяцем

union all
-- 2. Заказы: только положительные суммы
select 'orders: non_positive', coalesce(doc_id::text, 'null')
from etl.orders
where total <= 0

union all
-- 3. Заказы: один doc_id = один заказ.
-- Известное исключение: doc_id '15#17000300#66127#17_51' встречается дважды с разными картами, временем и суммами.
-- Это две разные покупки (по одному заказу на карту). Новые исключения добавляйте только после выяснения причины.
select 'orders: doc_id in several orders', coalesce(doc_id::text, 'null')
from etl.orders
where coalesce(doc_id::text, '') not in ('15#17000300#66127#17_51')
group by doc_id
having count(*) > 1

union all
-- 4. Таблицы не устарели: etl.clients относительно etl.orders
select 'stale: etl.clients revenue <> etl.orders',
	(select sum(total) from etl.orders)::text || ' vs ' || (select sum(total) from etl.clients)::text
where abs((select sum(total) from etl.orders) - (select sum(total) from etl.clients)) > 0.01

union all
-- 5. Таблицы не устарели: mart.client_ltv относительно etl.clients
select 'stale: mart.client_ltv clients <> etl.clients in scope',
	(select count(*) from mart.client_ltv)::text || ' vs ' || (select n from scope_clients)::text
where (select count(*) from mart.client_ltv) <> (select n from scope_clients)

union all
-- 6. Набор когорт равен календарю из параметров (без неполной последней когорты)
select 'cohorts: missing', e.cohort_month::text
from expected e
left join actual a on a.cohort_month = e.cohort_month
where a.cohort_month is null

union all
select 'cohorts: unexpected', a.cohort_month::text
from actual a
left join expected e on e.cohort_month = a.cohort_month
where e.cohort_month is null

union all
-- 7. Размеры когорт совпадают в etl.clients, mart.cohort_metrics и mart.retention_cohorts
select 'cohort sizes differ',
	m.cohort_month::text || ': metrics=' || m.cohort_size || ', retention=' || r.cohort_size || ', clients=' || c.n
from (select distinct cohort_month, cohort_size from mart.cohort_metrics) m
join (select distinct cohort, cohort_size from mart.retention_cohorts) r on r.cohort = m.cohort_month
join (select cohort_month, count(*) as n from etl.clients group by cohort_month) c on c.cohort_month = m.cohort_month
where m.cohort_size <> r.cohort_size
	or m.cohort_size <> c.n

union all
-- 8. Retention в mart.retention_cohorts и mart.cohort_metrics: правило зрелости и число клиентов совпадают
select 'retention mismatch', r.cohort::text || ' ' || r.period
from mart.retention_cohorts r
left join mart.cohort_metrics m
	on  m.cohort_month = r.cohort
	and m.window_no = split_part(r.period, '-', 2)::int / 30
where r.is_mature <> coalesce(m.is_complete, false)
	or (r.is_mature and (r.actual_users <> m.active_users or r.cohort_size <> m.eligible_users));
