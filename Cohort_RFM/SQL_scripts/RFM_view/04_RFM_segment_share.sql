create or replace
view mart.RFM_segment_share as (
	select
		rs.segment_group,
		count(rs.segment_group) as users_total,
		round(count(rs.rfm_segment)* 100 / (select count(*) from rfm_metrics)) as users_share,
		round(sum(rm.monetary)* 100 /(select sum(monetary) from rfm_metrics)) as monetary_share,
		sum(rm.monetary) as total_monetary
	from
		mart.rfm_segments rs
	left join
		mart.rfm_metrics as rm
		on
		rs.card = rm.card
	group by
		segment_group
	order by
		segment_group
)