"""
Функции пайплайна Cohort_RFM: выполнение SQL-файлов, проверки и выгрузка в Excel.

Модуль не читает конфигурацию и не хранит состояния: подключение (engine) и пути
(sql_root, data_dir) передаются параметрами из main.py.
"""
from __future__ import annotations

import logging
import re
import time
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL, Engine

logger = logging.getLogger(__name__)

MODES = {"read", "execute", "export", "auto"}
READ_KEYWORDS = {"SELECT", "WITH", "VALUES"}


class CheckFailed(AssertionError):
    """Проверка вернула строки-нарушения."""


def make_engine(db) -> Engine:
    """Подключение к PostgreSQL по параметрам из config (user, password, host, port, dbname)."""
    url = URL.create(
        "postgresql+psycopg2",
        username=db.user,
        password=db.password,
        host=db.host,
        port=int(db.port) if db.port else None,
        database=db.dbname,
    )
    return create_engine(url, pool_pre_ping=True)


def _first_keyword(query: str) -> str:
    """Первое ключевое слово SQL без учёта комментариев."""
    cleaned = re.sub(r"--[^\n]*|/\*.*?\*/", "", query, flags=re.S).strip()
    return cleaned.split(None, 1)[0].upper() if cleaned else ""


def _resolve_folder(folder, sql_root: Path) -> Path:
    """Папка: существующий путь или имя папки внутри sql_root."""
    path = Path(folder)
    if not path.is_dir():
        path = Path(sql_root) / folder
    if not path.is_dir():
        raise FileNotFoundError(f"Папка не найдена: {path}")
    return path


def _load_sql(sql, file, sql_root):
    """Текст запроса из строки или из .sql-файла; возвращает (путь или None, текст)."""
    if (sql is None) == (file is None):
        raise ValueError("Укажи ровно один аргумент: sql или file.")
    if file is None:
        return None, sql

    path = Path(file)
    if not path.is_absolute():
        if sql_root is None:
            raise ValueError("Для относительного пути укажи sql_root.")
        path = Path(sql_root) / path
    if not path.is_file():
        raise FileNotFoundError(f"SQL-файл не найден: {path}")
    return path, path.read_text(encoding="utf-8")


def run_sql(
    engine: Engine,
    sql: str | None = None,
    *,
    file=None,
    params: dict | None = None,
    mode: str = "auto",
    sql_root: Path | None = None,
    data_dir: Path | None = None,
):
    """
    Выполнить SQL-запрос или SQL-файл.

    mode:
      "read"    — вернуть pandas DataFrame;
      "execute" — выполнить SQL (в том числе скрипт из нескольких команд), файл целиком в одной транзакции;
      "export"  — выполнить SELECT и сохранить результат в data_dir/<имя_файла>.xlsx
                  ("update" — прежнее название этого режима);
      "auto"    — SELECT / WITH / VALUES читаем, остальное выполняем.
    """
    if mode == "update":
        mode = "export"
    if mode not in MODES:
        raise ValueError("mode должен быть 'read', 'execute', 'export' или 'auto'.")

    path, query = _load_sql(sql, file, sql_root)
    if not isinstance(query, str) or not query.strip():
        raise ValueError("SQL-запрос пустой.")

    if mode == "auto":
        mode = "read" if _first_keyword(query) in READ_KEYWORDS else "execute"

    if mode in {"read", "export"}:
        with engine.connect() as conn:
            df = pd.read_sql_query(text(query), conn, params=params)

        if mode == "read":
            return df

        if path is None or data_dir is None:
            raise ValueError("Для режима export нужны file и data_dir: по ним определяется Excel-файл.")
        data_dir = Path(data_dir)
        data_dir.mkdir(parents=True, exist_ok=True)
        excel_file = data_dir / f"{path.stem}.xlsx"
        df.to_excel(excel_file, index=False)
        logger.info("Сохранено: %s (%d строк)", excel_file.name, len(df))
        return df

    # execute: при ошибке откатывается весь файл
    with engine.begin() as conn:
        if params is not None:
            conn.execute(text(query), params)
        else:
            # raw cursor: скрипты из нескольких команд и знак % в LIKE '2000%'
            cursor = conn.connection.cursor()
            try:
                cursor.execute(query)
            finally:
                cursor.close()
    return None


def run_sql_folder(
    engine: Engine,
    folder,
    *,
    sql_root: Path,
    data_dir: Path | None = None,
    mode: str = "execute",
    stop_on_error: bool = True,
) -> list[str]:
    """
    Последовательно выполняет все .sql-файлы папки по алфавиту (отсюда числовые префиксы 01_, 02_, ...).
    Возвращает имена файлов с ошибками; при stop_on_error=True первая ошибка прерывает запуск.
    """
    folder_path = _resolve_folder(folder, sql_root)
    sql_files = sorted(folder_path.glob("*.sql"))
    if not sql_files:
        logger.warning("SQL-файлы не найдены: %s", folder_path)
        return []

    logger.info("Папка %s: файлов %d, режим %s", folder_path.name, len(sql_files), mode)
    failed: list[str] = []
    for sql_file in sql_files:
        started = time.perf_counter()
        try:
            run_sql(engine, file=sql_file, mode=mode, sql_root=sql_root, data_dir=data_dir)
        except Exception:
            logger.exception("Ошибка в %s", sql_file.name)
            failed.append(sql_file.name)
            if stop_on_error:
                raise
            continue
        logger.info("Готово: %s (%.1f с)", sql_file.name, time.perf_counter() - started)
    return failed


def run_checks(engine: Engine, folder, *, sql_root: Path) -> None:
    """Каждая проверка (SELECT) должна вернуть 0 строк. При нарушениях печатает их и бросает CheckFailed."""
    folder_path = _resolve_folder(folder, sql_root)
    failed: dict[str, int] = {}

    for sql_file in sorted(folder_path.glob("*.sql")):
        df = run_sql(engine, file=sql_file, mode="read", sql_root=sql_root)
        if df.empty:
            logger.info("Проверка %s/%s: OK", folder_path.name, sql_file.name)
            continue
        logger.error(
            "Проверка %s/%s: нарушений %d\n%s",
            folder_path.name, sql_file.name, len(df), df.head(20).to_string(index=False),
        )
        failed[f"{folder_path.name}/{sql_file.name}"] = len(df)

    if failed:
        raise CheckFailed(f"Не пройдены проверки: {failed}")
