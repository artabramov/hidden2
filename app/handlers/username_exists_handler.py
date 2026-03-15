# app/handlers/domain_error_handlers.py

from fastapi import Request, status
from fastapi.responses import JSONResponse

from app.errors import UsernameAlreadyExistsError


async def username_exists_handler(
    request: Request,
    exc: UsernameAlreadyExistsError,
) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content={
            "detail": [
                {
                    "type": "already_exists",
                    "loc": "username",
                    "msg": "Username already exists.",
                }
            ]
        },
    )
