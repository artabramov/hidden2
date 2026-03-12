import os
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Config(BaseSettings):
    """
    Config values are provided by the runtime environment (entrypoint
    script or container runtime) and validated by pydantic-settings at
    application startup.
    """
    LOG_LEVEL: str
    LOG_FORMAT: str

    MAINTENANCE_LOCK_PATH: str

    SECRETS_DIR: str

    GOCRYPTFS_CIPHERDIR: str
    GOCRYPTFS_MOUNTPOINT: str
    GOCRYPTFS_PASSPHRASE_LENGTH: int
    GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS: int

    RESTIC_ENABLED: bool
    RESTIC_REPOSITORY: Optional[str] = None
    RESTIC_CRON_SCHEDULE: Optional[str] = None
    RESTIC_FORGET_ARGS: Optional[str] = None

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
    def sqlite_path(self) -> str:
        """Absolute filesystem path to the SQLite database file."""
        return os.path.join(self.GOCRYPTFS_MOUNTPOINT, "hidden.db")

    @property
    def sqlite_url(self) -> str:
        """SQLAlchemy database URL for the SQLite backend."""
        return "sqlite+aiosqlite:///" + self.sqlite_path


config = Config()
