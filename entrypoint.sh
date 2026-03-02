#!/bin/sh

GOCRYPTFS_SECRETS_DIR="/etc/hidden"
GOCRYPTFS_CIPHERDIR="/var/lib/hidden/encrypted"
GOCRYPTFS_MOUNTPOINT="/var/lib/hidden/decrypted"

GOCRYPTFS_PASSPHRASE_FILENAME="gocryptfs.key"
GOCRYPTFS_PASSPHRASE_LENGTH=80
GOCRYPTFS_CONFIG_FILENAME="gocryptfs.conf"

mkdir -p "$GOCRYPTFS_SECRETS_DIR" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"

GOCRYPTFS_PASSPHRASE_PATH="${GOCRYPTFS_SECRETS_DIR}/${GOCRYPTFS_PASSPHRASE_FILENAME}"
GOCRYPTFS_CONFIG_PATH="${GOCRYPTFS_CIPHERDIR}/${GOCRYPTFS_CONFIG_FILENAME}"

# First boot: generate passphrase once (if missing)
if [ ! -f "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$GOCRYPTFS_PASSPHRASE_LENGTH" >"$GOCRYPTFS_PASSPHRASE_PATH"
  chmod 600 "$GOCRYPTFS_PASSPHRASE_PATH"
  echo "[gocryptfs] key generated: $GOCRYPTFS_PASSPHRASE_PATH"
fi

# Init only once (if missing config)
if [ ! -f "$GOCRYPTFS_CONFIG_PATH" ]; then
  gocryptfs -init -passfile "$GOCRYPTFS_PASSPHRASE_PATH" "$GOCRYPTFS_CIPHERDIR"
  echo "[gocryptfs] initialized: $GOCRYPTFS_CIPHERDIR"
fi

# Mount if not mounted
if command -v mountpoint >/dev/null 2>&1; then
  if ! mountpoint -q "$GOCRYPTFS_MOUNTPOINT"; then
    gocryptfs -passfile "$GOCRYPTFS_PASSPHRASE_PATH" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"
    echo "[gocryptfs] mounted: $GOCRYPTFS_MOUNTPOINT"
  fi
# Mount without pre-check (mountpoint utility is not available)
else
  gocryptfs -passfile "$GOCRYPTFS_PASSPHRASE_PATH" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"
  echo "[gocryptfs] mounted: $GOCRYPTFS_MOUNTPOINT"
fi

exec uvicorn app.main:app \
  --host "$UVICORN_HOST" \
  --port "$UVICORN_PORT" \
  --workers "$UVICORN_WORKERS"
