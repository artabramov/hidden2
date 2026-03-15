# app/models/folder.py

import time
from sqlalchemy import Column, BigInteger, String, Boolean, Integer
from app.db import Base


class Folder(Base):
    __tablename__ = "folders"
    __table_args__ = {"sqlite_autoincrement": True}

    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    created_date = Column(
        BigInteger,
        nullable=False,
        index=True,
        default=lambda: int(time.time())
    )

    updated_date = Column(
        BigInteger,
        nullable=False,
        index=True,
        default=lambda: int(time.time()),
        onupdate=lambda: int(time.time())
    )

    readonly = Column(
        Boolean,
        nullable=False,
    )

    name = Column(
        String(256),
        nullable=False,
        unique=True
    )

    summary = Column(
        String(4096),
        nullable=True
    )

    def __init__(self, readonly: bool, name: str, summary: str = None):
        self.readonly = readonly
        self.name = name
        self.summary = summary

    async def to_dict(self) -> dict:
        """Returns a dictionary representation of the folder."""
        return {
            "id": self.id,
            "created_date": self.created_date,
            "updated_date": self.updated_date,
            "readonly": self.readonly,
            "name": self.name,
            "summary": self.summary,
        }
