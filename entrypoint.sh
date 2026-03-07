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

# Validate integer values early, before doing any real work.
case "$GOCRYPTFS_PASSPHRASE_LENGTH" in
  ''|*[!0-9]*)
    echo "[fatal] GOCRYPTFS_PASSPHRASE_LENGTH must be an integer" >&2
    exit 1
    ;;
esac

case "$GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS" in
  ''|*[!0-9]*)
    echo "[fatal] GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS must be an integer" >&2
    exit 1
    ;;
esac

case "$UVICORN_PORT" in
  ''|*[!0-9]*)
    echo "[fatal] UVICORN_PORT must be an integer" >&2
    exit 1
    ;;
esac

case "$UVICORN_WORKERS" in
  ''|*[!0-9]*)
    echo "[fatal] UVICORN_WORKERS must be an integer" >&2
    exit 1
    ;;
esac

# Ensure required binaries are present in the image.
command -v gocryptfs >/dev/null 2>&1 || {
  echo "[fatal] gocryptfs is not installed" >&2
  exit 1
}

mkdir -p "$GOCRYPTFS_SECRETS_DIR" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"

GOCRYPTFS_PASSPHRASE_PATH="${GOCRYPTFS_SECRETS_DIR}/${GOCRYPTFS_PASSPHRASE_FILENAME}"
GOCRYPTFS_CONFIG_PATH="${GOCRYPTFS_CIPHERDIR}/gocryptfs.conf"

# First boot: generate passphrase once.
if [ ! -s "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
  # Head may terminate the pipe early; ignore the resulting SIGPIPE-related non-zero exit.
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$GOCRYPTFS_PASSPHRASE_LENGTH" >"$GOCRYPTFS_PASSPHRASE_PATH" || true

  if [ -s "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
    chmod 600 "$GOCRYPTFS_PASSPHRASE_PATH"
    echo "[gocryptfs] key generated: $GOCRYPTFS_PASSPHRASE_PATH"
  else
    echo "[fatal] failed to generate gocryptfs passphrase: $GOCRYPTFS_PASSPHRASE_PATH" >&2
    exit 1
  fi
fi

# Initialize cipherdir exactly once.
if [ ! -f "$GOCRYPTFS_CONFIG_PATH" ]; then
  # Suppress all init output because gocryptfs may print the master key.
  gocryptfs -nosyslog -init -passfile "$GOCRYPTFS_PASSPHRASE_PATH" "$GOCRYPTFS_CIPHERDIR" >/dev/null 2>&1
  echo "[gocryptfs] initialized: $GOCRYPTFS_CIPHERDIR"
fi

# Initial mount before application start.
# This removes the race where uvicorn starts before decrypted storage is available.
if command -v mountpoint >/dev/null 2>&1; then
  if [ -f "$GOCRYPTFS_CONFIG_PATH" ] && ! mountpoint -q "$GOCRYPTFS_MOUNTPOINT"; then
    gocryptfs -nosyslog -passfile "$GOCRYPTFS_PASSPHRASE_PATH" \
      "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"
    echo "[gocryptfs] mounted: $GOCRYPTFS_MOUNTPOINT"
  fi
else
  if [ -f "$GOCRYPTFS_CONFIG_PATH" ]; then
    gocryptfs -nosyslog -passfile "$GOCRYPTFS_PASSPHRASE_PATH" \
      "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"
    echo "[gocryptfs] mounted: $GOCRYPTFS_MOUNTPOINT"
  fi
fi

# Watchdog:
# - mount when passphrase exists and storage is not mounted
# - unmount when passphrase disappears
(
  while :; do
    if [ -s "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
      # Mount only if config exists and mountpoint is currently not mounted.
      if command -v mountpoint >/dev/null 2>&1; then
        if [ -f "$GOCRYPTFS_CONFIG_PATH" ] && ! mountpoint -q "$GOCRYPTFS_MOUNTPOINT"; then
          gocryptfs -nosyslog -passfile "$GOCRYPTFS_PASSPHRASE_PATH" \
            "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT" \
            && echo "[watchdog] mounted: $GOCRYPTFS_MOUNTPOINT" || true
        fi
      else
        # If mountpoint utility is unavailable, just try mounting.
        if [ -f "$GOCRYPTFS_CONFIG_PATH" ]; then
          gocryptfs -nosyslog -passfile "$GOCRYPTFS_PASSPHRASE_PATH" \
            "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT" >/dev/null 2>&1 \
            && echo "[watchdog] mounted: $GOCRYPTFS_MOUNTPOINT" || true
        fi
      fi
    else
      # Passphrase missing: unmount if mounted.
      if command -v mountpoint >/dev/null 2>&1; then
        if mountpoint -q "$GOCRYPTFS_MOUNTPOINT"; then
          (
            fusermount3 -u "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
            fusermount3 -uz "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
            fusermount -u "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
            fusermount -uz "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
            umount "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
            gocryptfs -q -u "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null
          ) && echo "[watchdog] unmounted: $GOCRYPTFS_MOUNTPOINT" || true
        fi
      else
        # Without mountpoint utility, attempt unmount anyway.
        (
          fusermount3 -u "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
          fusermount3 -uz "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
          fusermount -u "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
          fusermount -uz "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
          umount "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null || \
          gocryptfs -q -u "$GOCRYPTFS_MOUNTPOINT" 2>/dev/null
        ) && echo "[watchdog] unmounted: $GOCRYPTFS_MOUNTPOINT" || true
      fi
    fi

    sleep "$GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS"
  done
) &

if [ -x /opt/hidden/.venv/bin/uvicorn ]; then
  UVICORN_BIN=/opt/hidden/.venv/bin/uvicorn
else
  UVICORN_BIN=uvicorn
fi

# Make uvicorn PID 1 so it receives signals directly.
exec "$UVICORN_BIN" app.main:app \
  --host "$UVICORN_HOST" \
  --port "$UVICORN_PORT" \
  --workers "$UVICORN_WORKERS"
