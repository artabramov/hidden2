#!/bin/sh
set -eu
umask 077

: "${GOCRYPTFS_SECRETS_DIR:?GOCRYPTFS_SECRETS_DIR is not defined}"
: "${GOCRYPTFS_CIPHERDIR:?GOCRYPTFS_CIPHERDIR is not defined}"
: "${GOCRYPTFS_MOUNTPOINT:?GOCRYPTFS_MOUNTPOINT is not defined}"
: "${GOCRYPTFS_PASSPHRASE_FILENAME:?GOCRYPTFS_PASSPHRASE_FILENAME is not defined}"
: "${GOCRYPTFS_PASSPHRASE_LENGTH:?GOCRYPTFS_PASSPHRASE_LENGTH is not defined}"
: "${GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS:?GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS is not defined}"
: "${UVICORN_HOST:?UVICORN_HOST is not defined}"
: "${UVICORN_PORT:?UVICORN_PORT is not defined}"
: "${UVICORN_WORKERS:?UVICORN_WORKERS is not defined}"

mkdir -p "$GOCRYPTFS_SECRETS_DIR" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"

GOCRYPTFS_PASSPHRASE_PATH="${GOCRYPTFS_SECRETS_DIR}/${GOCRYPTFS_PASSPHRASE_FILENAME}"
GOCRYPTFS_CONFIG_PATH="${GOCRYPTFS_CIPHERDIR}/gocryptfs.conf"

# First boot: generate passphrase once (if missing)
if [ ! -f "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
  ( tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$GOCRYPTFS_PASSPHRASE_LENGTH" >"$GOCRYPTFS_PASSPHRASE_PATH" ) || true
  if [ -s "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
    chmod 600 "$GOCRYPTFS_PASSPHRASE_PATH"
    echo "[gocryptfs] key generated: $GOCRYPTFS_PASSPHRASE_PATH"
  else
    echo "[fatal] failed to generate gocryptfs passphrase: $GOCRYPTFS_PASSPHRASE_PATH"
    exit 1
  fi
fi

# Init only once (if missing config)
if [ ! -f "$GOCRYPTFS_CONFIG_PATH" ]; then
  gocryptfs -nosyslog -init -passfile "$GOCRYPTFS_PASSPHRASE_PATH" "$GOCRYPTFS_CIPHERDIR" >/dev/null 2>&1
  echo "[gocryptfs] initialized: $GOCRYPTFS_CIPHERDIR"
fi

# Watchdog: mount when key exists; unmount when key is missing
(
  while :; do
    if [ -f "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
      # Mount when not mounted
      if command -v mountpoint >/dev/null 2>&1; then
        if [ -f "$GOCRYPTFS_CONFIG_PATH" ] && ! mountpoint -q "$GOCRYPTFS_MOUNTPOINT"; then
          gocryptfs -nosyslog -passfile "$GOCRYPTFS_PASSPHRASE_PATH" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT" \
            && echo "[watchdog] mounted: $GOCRYPTFS_MOUNTPOINT" || true
        fi
      else
        # No mountpoint: just try mounting; ignore failure
        if [ -f "$GOCRYPTFS_CONFIG_PATH" ]; then
          gocryptfs -nosyslog -passfile "$GOCRYPTFS_PASSPHRASE_PATH" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT" >/dev/null 2>&1 \
            && echo "[watchdog] mounted: $GOCRYPTFS_MOUNTPOINT" || true
        fi
      fi
    else
      # Passphrase missing: unmount if currently mounted
      if command -v mountpoint >/dev/null 2>&1; then
        if mountpoint -q "$GOCRYPTFS_MOUNTPOINT"; then
          ( fusermount -u "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
            fusermount -uz "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
            umount "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
            gocryptfs -q -u "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null ) \
            && echo "[watchdog] unmounted: $GOCRYPTFS_MOUNTPOINT" || true
        fi
      else
        # Without mountpoint check: attempt unmount anyway
        ( fusermount -u "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
          fusermount -uz "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
          umount "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
          gocryptfs -q -u "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null ) \
          && echo "[watchdog] unmounted: $GOCRYPTFS_MOUNTPOINT" || true
      fi
    fi

    sleep "$GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS"
  done
) &

# Make uvicorn PID 1 so it receives signals directly.
exec uvicorn app.main:app \
  --host "$UVICORN_HOST" \
  --port "$UVICORN_PORT" \
  --workers "$UVICORN_WORKERS"
