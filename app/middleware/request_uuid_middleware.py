# app/middleware/request_uuid_middleware.py

import uuid
from fastapi import Request


async def request_uuid_middleware(request: Request, call_next):
    request_uuid = request.headers.get("X-Request-ID") or uuid.uuid4().hex
    request.state.request_uuid = request_uuid

    response = await call_next(request)

    response.headers["X-Request-ID"] = request_uuid
    return response
