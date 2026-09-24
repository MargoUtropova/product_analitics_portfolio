from dataclasses import dataclass
from environs import Env


@dataclass
class LogSettings:
    """Настройки логирования."""
    level: str
    format: str


@dataclass
class DataBase:
    """ настройки доступа """
    host: str        # или IP сервера
    port: str
    dbname: str       # база, которую создали в pgAdmin
    user: str
    password: str

@dataclass
class Config:
    database:DataBase
    log: LogSettings


def load_config(path: str | None = None) -> Config:
    """Загружает настройки из файла .env.

    Args:
        path: Необязательный путь к файлу с переменными окружения.
              Если путь не указан, environs ищет .env автоматически.

    Returns:
        Объект Config с настройками бота и логирования.
    """

    env = Env()

    # Если путь не указан, environs ищет файл .env
    # в текущей директории и родительских директориях.
    if path is None:
        env.read_env()
    else:
        env.read_env(path)

    return Config(
        database=DataBase(
            host=env("HOST"),      # или IP сервера
            port=env("PORT"),
            dbname=env("DBNAME") ,     # база, которую создали в pgAdmin
            user=env("USER"),
            password=env("PASSWORD"),
        ),
        log=LogSettings(
            level=env("LOG_LEVEL"),
            format=env("LOG_FORMAT"),
        ),
    )