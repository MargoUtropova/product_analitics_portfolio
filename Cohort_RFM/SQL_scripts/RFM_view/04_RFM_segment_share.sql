-- Доли клиентов и выручки по группам RFM.
-- drop view: типы колонок изменились (доли теперь с десятичным знаком), create or replace не пройдёт.
drop view if exists mart.rfm_segment_share;

create view mart.rfm_segment_share as (
	select
		rs.segment_group,
		count(rs.segment_group) as users_total,
		round(count(rs.rfm_segment) * 100.0 / (select count(*) from mart.rfm_metrics), 1) as users_share,
		round(sum(rm.monetary) * 100.0 / (select sum(monetary) from mart.rfm_metrics), 1) as monetary_share,
		sum(rm.monetary) as total_monetary
	from
		mart.rfm_segments rs
	left join
		mart.rfm_metrics as rm
		on rs.card = rm.card
	group by
		rs.segment_group
	order by
		rs.segment_group
);