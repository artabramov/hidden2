# app/handlers/validation_error.py

from fastapi import Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


async def validation_error_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    details = []

    for error in exc.errors():
        loc = list(error["loc"])

        # remove "body" prefix
        if loc and loc[0] == "body":
            loc = loc[1:]

        details.append(
            {
                "type": error["type"],
                "loc": ".".join(loc),
                "msg": error["msg"],
            }
        )

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": details},
    )
