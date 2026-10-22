-- 03_etl_clients.sql: клиенты (таблица). После любого изменения etl.orders или params пересоздаётся.
drop table if exists etl.clients cascade;

create table etl.clients as
select
	card,
	min(order_date) as first_purchase,
	max(order_date) as last_purchase,
	sum(total) as total,
	count(*) as total_orders,                -- число чеков
	min(order_date) as anchor_date,
	date_trunc('month', min(order_date))::date as cohort_month
from
	etl.orders
group by
	card;

create index idx_etl_clients_card on etl.clients (card);
