from dataclasses import dataclass, field

from environs import Env


@dataclass
class LogSettings:
    """Настройки логирования."""
    level: str
    format: str


@dataclass
class DataBase:
    """Настройки доступа к базе данных."""
    host: str                           # или IP сервера
    port: int
    dbname: str                         # база, которую создали в pgAdmin
    user: str
    password: str = field(repr=False)   # не попадает в repr и в логи


@dataclass
class Config:
    database: DataBase
    log: LogSettings


def load_config(path: str | None = None) -> Config:
    """Загружает настройки из файла .env.

    Args:
        path: Необязательный путь к файлу с переменными окружения.
              Если путь не указан, environs ищет .env автоматически.

    Returns:
        Объект Config с настройками базы данных и логирования.
    """

    env = Env()

    # Если путь не указан, environs ищет файл .env
    # в директории этого файла и родительских директориях.
    if path is None:
        env.read_env()
    else:
        env.read_env(path)

    return Config(
        database=DataBase(
            host=env.str("DB_HOST"),            # или IP сервера
            port=env.int("DB_PORT", 5432),
            dbname=env.str("DB_NAME"),          # база, которую создали в pgAdmin
            user=env.str("DB_USER"),
            password=env.str("DB_PASSWORD"),
        ),
        log=LogSettings(
            level=env.str("LOG_LEVEL"),
            format=env.str("LOG_FORMAT"),
        ),
    )
