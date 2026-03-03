#!/bin/sh

set -eu

mkdir -p "$GOCRYPTFS_SECRETS_DIR" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"

GOCRYPTFS_PASSPHRASE_PATH="${GOCRYPTFS_SECRETS_DIR}/${GOCRYPTFS_PASSPHRASE_FILENAME}"
GOCRYPTFS_CONFIG_PATH="${GOCRYPTFS_CIPHERDIR}/gocryptfs.conf"

# First boot: generate passphrase once (if missing)
if [ ! -f "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$GOCRYPTFS_PASSPHRASE_LENGTH" >"$GOCRYPTFS_PASSPHRASE_PATH"
  chmod 600 "$GOCRYPTFS_PASSPHRASE_PATH"
  echo "[gocryptfs] key generated: $GOCRYPTFS_PASSPHRASE_PATH"
fi

# Init only once (if missing config)
if [ ! -f "$GOCRYPTFS_CONFIG_PATH" ]; then
  gocryptfs -nosyslog -init -passfile "$GOCRYPTFS_PASSPHRASE_PATH" "$GOCRYPTFS_CIPHERDIR"
  echo "[gocryptfs] initialized: $GOCRYPTFS_CIPHERDIR"
fi

# Mount if not mounted
if command -v mountpoint >/dev/null 2>&1; then
  if ! mountpoint -q "$GOCRYPTFS_MOUNTPOINT"; then
    gocryptfs -nosyslog -passfile "$GOCRYPTFS_PASSPHRASE_PATH" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"
    echo "[gocryptfs] mounted: $GOCRYPTFS_MOUNTPOINT"
  fi
# Mount without pre-check (mountpoint utility is not available)
else
  gocryptfs -nosyslog -passfile "$GOCRYPTFS_PASSPHRASE_PATH" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"
  echo "[gocryptfs] mounted: $GOCRYPTFS_MOUNTPOINT"
fi

exec uvicorn app.main:app \
  --host "$UVICORN_HOST" \
  --port "$UVICORN_PORT" \
  --workers "$UVICORN_WORKERS"
