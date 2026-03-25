create view RFM_segment_share as (select
	rfm_segment,
	count(card) as customers_count,
	to_char(round(count(card) * 100.0 / (select count(*) from rfm_metrics), 2), 'fm00D00%') as share
from
	rfm_segments
group by
	rfm_segment)