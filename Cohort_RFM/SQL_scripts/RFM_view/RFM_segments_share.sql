create or replace view RFM_segment_share as (select rfm_segment, count(rfm_segment) as total,
to_char(round(count(rfm_segment)*100/ (select count(*) from rfm_customer_metrics),2),'fm00D00%') as share
from view_rfm_segments vrs
group by rfm_segment
order by rfm_segment)