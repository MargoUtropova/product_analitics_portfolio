create or replace view mart.rfm_metrics as
select
	c.card,
	p.data_end - c.last_purchase as recency,       -- дней с последней покупки до последнего дня данных
	c.total_orders               as frequency,     -- число чеков (раньше считались строки таблицы)
	c.total                      as monetary       -- сумма положительных чеков
from
	etl.clients c
cross join etl.params p;