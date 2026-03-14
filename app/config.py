import os
from typing import Optional
from pydantic import PrivateAttr
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

    JWT_SIGNING_KEY_PATH: str
    JWT_SIGNING_KEY_LENGTH: int

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

    _jwt_signing_key: str = PrivateAttr()

    model_config = SettingsConfigDict(
        extra="ignore",
    )

    def __init__(self, **data):
        super().__init__(**data)

        with open(self.JWT_SIGNING_KEY_PATH, "r", encoding="utf-8") as f:
            self._jwt_signing_key = f.read().strip()

    @property
    def GOCRYPTFS_KEY_PATH(self) -> str:
        """Absolute filesystem path to the gocryptfs passphrase file."""
        return os.path.join(self.SECRETS_DIR, "gocryptfs.key")


    @property
    def SQLITE_PATH(self) -> str:
        """Absolute filesystem path to the SQLite database file."""
        return os.path.join(
            self.GOCRYPTFS_MOUNTPOINT,
            "db/hidden.db"
        )

    @property
    def SQLITE_URL(self) -> str:
        """SQLAlchemy database URL for the SQLite backend."""
        return "sqlite+aiosqlite:///" + self.SQLITE_PATH

    @property
    def JWT_SIGNING_KEY(self) -> str:
        """JWT signing secret loaded at startup and kept in memory."""
        return self._jwt_signing_key


config = Config()
