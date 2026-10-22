-- Накопленный LTV на клиента к дням 0, 30, 60, ..., 180: формат таблицы LTV_Cohorts в Power BI (Когорта, Период, Значение).
-- Только полностью наблюдаемые ячейки: у края данных значения занижены (клиенты, у которых день ещё не наступил).
select
	cohort_month as "Когорта",
	day_k        as "Период",
	ltv          as "Значение"
from mart.cohort_metrics
where is_complete
order by cohort_month, day_k;