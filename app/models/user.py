# app/models/user.py

from datetime import datetime
from enum import StrEnum

from sqlalchemy import String, Integer, SmallInteger, DateTime, Boolean, CheckConstraint, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class UserRole(StrEnum):
    READER = "reader"
    WRITER = "writer"
    EDITOR = "editor"
    ADMIN = "admin"


class User(Base):
    __tablename__ = "users"

    __table_args__ = (
        CheckConstraint(
            "role IN ('reader', 'writer', 'editor', 'admin')",
            name="ck_users_role",
        ),
        {"sqlite_autoincrement": True},
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    suspended_until: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
    )

    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
    )

    role: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        server_default=text("'reader'"),
        index=True,
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=text("0"),
    )

    username: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        unique=True,
    )

    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    failed_password_attempts: Mapped[int] = mapped_column(
        SmallInteger,
        nullable=False,
        server_default=text("0"),
    )

    is_password_verified: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=text("0"),
    )

    totp_secret_encrypted: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    failed_totp_attempts: Mapped[int] = mapped_column(
        SmallInteger,
        nullable=False,
        server_default=text("0"),
    )

    current_jti_encrypted: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    first_name: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        index=True,
    )

    last_name: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        index=True,
    )

    summary: Mapped[str | None] = mapped_column(
        String(4096),
        nullable=True,
    )
