from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.repositories.orm import ORMRepository


def get_orm_repository(
    session: AsyncSession = Depends(get_session),
) -> ORMRepository:
    return ORMRepository(session)
