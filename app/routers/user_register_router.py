from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.error import HTTPError
from app.repositories.orm_repository import ORMRepository
from app.schemas.user_register_schema import (
    UserRegisterRequest,
    UserRegisterResponse,
)
from app.services.user_register_service import register_user


router = APIRouter(
    prefix="/users",
    tags=["users"],
)


@router.post(
    "/register",
    response_model=UserRegisterResponse,
    status_code=status.HTTP_201_CREATED,
)
async def user_register_router(
    request: UserRegisterRequest,
    session: AsyncSession = Depends(get_session),
) -> UserRegisterResponse:
    repository = ORMRepository(session)

    try:
        user, totp_secret = await register_user(repository, request)
    except ValueError:
        raise HTTPError(
            status_code=status.HTTP_409_CONFLICT,
            loc=["body", "username"],
            msg="Username already exists.",
            error_type="value_error.username_exists",
            error_input=request.username,
        )

    return UserRegisterResponse(
        id=user.id,
        totp_secret=totp_secret,
    )
