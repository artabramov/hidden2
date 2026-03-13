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

    RESTIC_ENABLED: int
    RESTIC_PASSWORD_LENGTH: Optional[int] = None
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
    def GOCRYPTFS_KEY_PATH(self) -> str:
        """Absolute filesystem path to the gocryptfs passphrase file."""
        return os.path.join(config.SECRETS_DIR, "gocryptfs.key")


    @property
    def SQLITE_PATH(self) -> str:
        return os.path.join(
            self.GOCRYPTFS_MOUNTPOINT,
            "db/hidden.db"
        )

    @property
    def SQLITE_URL(self) -> str:
        """SQLAlchemy database URL for the SQLite backend."""
        return "sqlite+aiosqlite:///" + self.SQLITE_PATH


config = Config()
