# app/middleware/maintenance_lock_middleware.py

import os

from fastapi import Request
from starlette.responses import JSONResponse

from app.config import config


MAINTENANCE_EXCLUDED_PATHS = {
    "/health", "/metrics"
}


async def maintenance_lock_middleware(request: Request, call_next):
    if request.url.path not in MAINTENANCE_EXCLUDED_PATHS:
        if os.path.exists(config.MAINTENANCE_LOCK_PATH):
            return JSONResponse(
                status_code=503,
                content={"detail": "Service temporarily unavailable"},
                headers={"Retry-After": "300"},
            )

    return await call_next(request)