select rfm_segment, sum(monetary) as total,
to_char(round(sum(monetary)*100/(select sum(monetary) from rfm_metrics),2),'fm00D00%') as share
from
(
SELECT
    s.customer_card,
    s.rfm_segment,
    m.monetary
FROM rfm_segments s
LEFT JOIN rfm_metrics m ON s.customer_card = m.card
) as t
group by rfm_segment