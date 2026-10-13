create or replace
view rfm_segments_with_monetary as
select
	s.customer_card,
	s.rfm_segment,
	m.monetary
from
	rfm_segments s
left join rfm_metrics m on
	s.card = m.card;