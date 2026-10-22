-- Retention факт (зрелые окна) и прогноз (незрелые окна).
-- window_no и day_k — ключи для связи с таблицей ARPPU_LTV_report по (cohort, window_no) и для сортировки периодов в Power BI
-- (текстовые периоды '1-30', '121-150', ... сортируются по алфавиту).
select
	r.*,
	split_part(r.period, '-', 2)::int / 30 as window_no,
	split_part(r.period, '-', 2)::int      as day_k
from mart.retention_cohorts r
order by r.cohort, window_no;