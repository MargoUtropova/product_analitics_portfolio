-- 02_etl_orders.sql: заказ = чек (doc_id) с положительным итогом
-- После DROP ... CASCADE в 01_params.sql представление создаётся заново.
create or replace view etl.orders as
select
	datetime::date as order_date,
	card,
	sum(summ_with_disc) as total,
	doc_id
from
	checks c,
	etl.params p
where
	card like '2000%'
	and datetime::date between '2000-01-01' and p.data_end
group by
	doc_id,
	datetime::date,
	card
having
	sum(summ_with_disc) > 0;
