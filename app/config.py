from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    SQLITE_DIR: str
    SQLITE_FILENAME: str
    SQLITE_JOURNAL_MODE: str
    SQLITE_SYNCHRONOUS: str
    SQLITE_BUSY_TIMEOUT: int
    SQLITE_TEMP_STORE: str

    UVICORN_HOST: str
    UVICORN_PORT: int

    model_config = SettingsConfigDict(
        extra="ignore",
    )

    @property
    def sqlite_path(self) -> Path:
        return Path(self.SQLITE_DIR) / self.SQLITE_FILENAME

    @property
    def database_url(self) -> str:
        return f"sqlite+aiosqlite:///{self.sqlite_path}"


settings = Settings()
