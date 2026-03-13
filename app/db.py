from collections.abc import AsyncGenerator
from sqlalchemy import event
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase
from app.config import config


class Base(DeclarativeBase):
    """
    Declarative base class for all ORM models.
    Registers models in the shared SQLAlchemy metadata.
    """
    pass


engine = create_async_engine(
    config.SQLITE_URL,
)

SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    autoflush=False,
    expire_on_commit=False,
)


@event.listens_for(engine.sync_engine, "connect")
def set_sqlite_pragma(dbapi_connection, _connection_record) -> None:
    """
    Apply SQLite PRAGMA settings for each new database connection.
    These values are provided through the application configuration.
    """
    cursor = dbapi_connection.cursor()
    cursor.execute(f"PRAGMA journal_mode={config.SQLITE_JOURNAL_MODE}")
    cursor.execute(f"PRAGMA synchronous={config.SQLITE_SYNCHRONOUS}")
    cursor.execute(f"PRAGMA busy_timeout={config.SQLITE_BUSY_TIMEOUT}")
    cursor.execute(f"PRAGMA temp_store={config.SQLITE_TEMP_STORE}")
    cursor.close()


async def init_db() -> None:
    """
    Create database tables if they do not exist yet.
    """
    from app.models.folder import Folder
    from app.models.user import User
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """
    Provide a database session for a single request.
    The session is automatically closed after the request finishes.
    """
    async with SessionLocal() as session:
        yield session
