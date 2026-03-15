from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.repositories.orm_repository import ORMRepository
from app.schemas.user_register_request import UserRegisterRequest
from app.schemas.user_register_response import UserRegisterResponse
from app.services.user_register_service import register_user
from app.errors import UsernameAlreadyExistsError


router = APIRouter(
    prefix="/users",
    tags=["users"],
)


@router.post(
    "/register",
    response_model=UserRegisterResponse,
    status_code=status.HTTP_201_CREATED,
)
async def user_register(
    request: UserRegisterRequest,
    session: AsyncSession = Depends(get_session),
) -> UserRegisterResponse:

    repository = ORMRepository(session)
    user, totp_secret = await register_user(repository, request)

    return UserRegisterResponse(
        id=user.id,
        totp_secret=totp_secret,
    )
