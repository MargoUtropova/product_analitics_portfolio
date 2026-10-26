"""Запуск проекта: пересборка таблиц в БД, проверки и выгрузка отчётов в Excel для Power BI."""
import logging
from pathlib import Path

from config.config import load_config
from funcs.funcs import make_engine, run_checks, run_sql_folder

PROJECT_ROOT = Path(__file__).resolve().parent
SQL_ROOT = PROJECT_ROOT / "SQL_scripts"
DATA_DIR = PROJECT_ROOT / "data"
LOG_DIR = PROJECT_ROOT / "logs"


def main():
    # Настройки из .env
    config = load_config(str(PROJECT_ROOT / ".env"))

    # Лог в консоль и в файл
    LOG_DIR.mkdir(exist_ok=True)
    logging.basicConfig(
        level=config.log.level,
        format=config.log.format,
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(LOG_DIR / "pipeline.log", encoding="utf-8"),
        ],
    )
    logger = logging.getLogger("cohort_rfm")
    logger.info("База данных: %s", config.database.dbname)

    engine = make_engine(config.database)

    # 1. Пересобираем таблицы и представления (файлы запускаются по номерам 01_, 02_, ...)
    run_sql_folder(engine, "Cohort_setup", sql_root=SQL_ROOT, mode="execute")
    run_sql_folder(engine, "RFM_view", sql_root=SQL_ROOT, mode="execute")

    # 2. Проверки: если хоть одна не пройдена, выгрузка не запускается
    run_checks(engine, "Cohort_checks", sql_root=SQL_ROOT)
    run_checks(engine, "RFM_checks", sql_root=SQL_ROOT)

    # 3. Выгрузка отчётов в Excel
    run_sql_folder(engine, "Cohort_reports", sql_root=SQL_ROOT, data_dir=DATA_DIR, mode="export")
    run_sql_folder(engine, "RFM_reports", sql_root=SQL_ROOT, data_dir=DATA_DIR, mode="export")

    logger.info("Готово")


if __name__ == "__main__":
    main()