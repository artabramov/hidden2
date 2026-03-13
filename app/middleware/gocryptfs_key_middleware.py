# app/middleware/gocryptfs_key_middleware.py

import os
from fastapi import Request
from fastapi.responses import JSONResponse
from app.config import config

GOCRYPTFS_KEY_PATH = os.path.join(config.SECRETS_DIR, "gocryptfs.key")
GOCRYPTFS_EXCLUDED_PATHS = {
    "/health",
}


async def gocryptfs_key_middleware(request: Request, call_next):
    path = request.url.path.rstrip("/") or "/"
    if path in GOCRYPTFS_EXCLUDED_PATHS:
        return await call_next(request)

    # Scenario 1: key is missing
    if not os.path.isfile(GOCRYPTFS_KEY_PATH):
        return JSONResponse(
            status_code=503,
            content={"detail": "Encryption key is missing"},
        )

    # Scenario 2: key exists but storage is not mounted
    if not os.path.ismount(config.GOCRYPTFS_MOUNTPOINT):
        return JSONResponse(
            status_code=503,
            content={"detail": "Encryption storage is unavailable"},
        )

    return await call_next(request)
