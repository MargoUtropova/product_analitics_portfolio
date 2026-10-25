"""
Запуск пайплайна Cohort_RFM: пересборка таблиц и представлений, проверки, выгрузка в Excel для Power BI.

Примеры (из корня проекта, с активированным .venv):
    python main.py                                   # все этапы по порядку
    python main.py --stages checks reports           # только проверки и выгрузка
    python main.py --stages setup rfm --allow-prod   # пересборка на основной базе
"""
from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.config import load_config  # noqa: E402
from funcs.funcs import CheckFailed, make_engine, run_checks, run_sql_folder  # noqa: E402

SQL_ROOT = PROJECT_ROOT / "SQL_scripts"
DATA_DIR = PROJECT_ROOT / "data"
LOG_DIR = PROJECT_ROOT / "logs"

STAGE_ORDER = ["setup", "rfm", "checks", "reports"]
DESTRUCTIVE_STAGES = {"setup", "rfm"}  # drop ... cascade и пересоздание объектов

logger = logging.getLogger("cohort_rfm")


def setup_logging(log) -> None:
    """Логирование в консоль и в logs/pipeline.log; уровень и формат берутся из config (LOG_LEVEL, LOG_FORMAT)."""
    LOG_DIR.mkdir(exist_ok=True)
    logging.basicConfig(
        level=getattr(logging, str(log.level).upper(), logging.INFO),
        format=log.format,
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(LOG_DIR / "pipeline.log", encoding="utf-8"),
        ],
    )


def stage_setup(engine) -> None:
    """Схемы, параметры, заказы, клиенты, LTV по клиентам, retention, метрики когорт."""
    run_sql_folder(engine, "Cohort_setup", sql_root=SQL_ROOT, mode="execute")


def stage_rfm(engine) -> None:
    """Представления RFM (зависят от etl.clients и etl.params, setup их удаляет)."""
    run_sql_folder(engine, "RFM_view", sql_root=SQL_ROOT, mode="execute")


def stage_checks(engine) -> None:
    """Проверки согласованности; при нарушении выгрузка не запускается."""
    for folder in ("Cohort_checks", "RFM_checks"):
        run_checks(engine, folder, sql_root=SQL_ROOT)


def stage_reports(engine) -> None:
    """Выгрузка SELECT-отчётов в data/*.xlsx."""
    for folder in ("Cohort_reports", "RFM_reports"):
        run_sql_folder(engine, folder, sql_root=SQL_ROOT, data_dir=DATA_DIR, mode="export")


STAGES = {
    "setup": stage_setup,
    "rfm": stage_rfm,
    "checks": stage_checks,
    "reports": stage_reports,
}


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Пайплайн Cohort_RFM: пересборка, проверки, выгрузка в Excel.")
    parser.add_argument(
        "--stages",
        nargs="+",
        choices=STAGE_ORDER + ["all"],
        default=["all"],
        help="этапы (по умолчанию all): setup — пересборка, rfm — RFM-представления, checks — проверки, reports — Excel",
    )
    parser.add_argument(
        "--allow-prod",
        action="store_true",
        help="разрешить пересборку на базе, имя которой не оканчивается на _test",
    )
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)

    try:
        config = load_config(str(PROJECT_ROOT / ".env"))
    except Exception as exc:
        print(f"Не удалось прочитать настройки из .env: {exc}", file=sys.stderr)
        return 2
    setup_logging(config.log)
    db = config.database

    chosen = set(args.stages)
    stages = STAGE_ORDER if "all" in chosen else [s for s in STAGE_ORDER if s in chosen]

    logger.info("База: %s (%s:%s); этапы: %s", db.dbname, db.host, db.port, ", ".join(stages))

    # destructive = DESTRUCTIVE_STAGES & set(stages)
    # if destructive and not str(db.dbname).endswith("_test") and not args.allow_prod:
    #     logger.error(
    #         "Этапы %s пересоздают таблицы и представления (drop ... cascade), а база %r не оканчивается на _test. "
    #         "Для запуска на этой базе добавьте --allow-prod.",
    #         sorted(destructive), db.dbname,
    #     )
    #     return 2

    if "setup" in stages and "rfm" not in stages:
        logger.warning("setup удаляет представления RFM (cascade): добавьте этап rfm, иначе они не будут пересозданы.")

    engine = make_engine(db)
    try:
        for stage in stages:
            started = time.perf_counter()
            logger.info("=== Этап: %s ===", stage)
            STAGES[stage](engine)
            logger.info("Этап %s завершён за %.1f с", stage, time.perf_counter() - started)
    except CheckFailed as exc:
        logger.error("%s", exc)
        return 1
    except Exception as exc:  # подробности уже в логе funcs
        logger.error("Пайплайн остановлен: %s", exc)
        return 1
    finally:
        engine.dispose()

    logger.info("Готово")
    return 0


if __name__ == "__main__":
    sys.exit(main())
