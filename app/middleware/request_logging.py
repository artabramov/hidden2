# app/middleware/request_logging.py

import logging
import time
from fastapi import Request

logger = logging.getLogger("app.request")


async def request_logging_middleware(request: Request, call_next):
    request_uuid = request.state.request_uuid
    client = request.client.host if request.client else None
    start_time = time.perf_counter()

    logger.info(
        "request received request_uuid=%s method=%s "
        "url=%s client=%s",
        request_uuid,
        request.method,
        request.url,
        client,
    )

    try:
        response = await call_next(request)

    except Exception:
        elapsed_time = time.perf_counter() - start_time
        logger.exception(
            "request failed request_uuid=%s method=%s "
            "url=%s client=%s elapsed_time=%.6f",
            request_uuid,
            request.method,
            request.url,
            client,
            elapsed_time,
        )
        raise

    elapsed_time = time.perf_counter() - start_time
    logger.info(
        "request finished request_uuid=%s method=%s url=%s "
        "client=%s status_code=%s elapsed_time=%.6f",
        request_uuid,
        request.method,
        request.url,
        client,
        response.status_code,
        elapsed_time,
    )
    return response