#!/usr/bin/env sh

exec uvicorn app.main:app \
  --host "$UVICORN_HOST" \
  --port "$UVICORN_PORT" \
  --workers "$UVICORN_WORKERS"
