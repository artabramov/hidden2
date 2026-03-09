#!/bin/sh
set -eu
umask 077

SECRETS_DIR=/etc/hidden
ENV_FILENAME=hidden.env
ENV_PATH="${SECRETS_DIR}/${ENV_FILENAME}"

# ensure secrets directory exists
mkdir -p "$SECRETS_DIR"

# create env file on first run
if [ ! -f "$ENV_PATH" ]; then
    cp /opt/hidden/.env.example "$ENV_PATH"
    chmod 600 "$ENV_PATH"
    echo "[hidden] created default env: $ENV_PATH"
fi

# load environment variables
set -a
. "$ENV_PATH"
set +a

: "${GOCRYPTFS_CIPHERDIR:?GOCRYPTFS_CIPHERDIR is not defined}"
: "${GOCRYPTFS_MOUNTPOINT:?GOCRYPTFS_MOUNTPOINT is not defined}"
: "${GOCRYPTFS_PASSPHRASE_LENGTH:?GOCRYPTFS_PASSPHRASE_LENGTH is not defined}"
: "${GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS:?GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS is not defined}"
: "${UVICORN_HOST:?UVICORN_HOST is not defined}"
: "${UVICORN_PORT:?UVICORN_PORT is not defined}"

: "${RESTIC_ENABLED:?RESTIC_ENABLED is not defined}"
if [ "$RESTIC_ENABLED" = "true" ]; then
  : "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY is not defined}"
  : "${RESTIC_CRON_SCHEDULE:?RESTIC_CRON_SCHEDULE is not defined}"
  : "${RESTIC_FORGET_ARGS:?RESTIC_FORGET_ARGS is not defined}"
fi

# Ensure required gocryptfs binaries are present.
command -v gocryptfs >/dev/null 2>&1 || {
  echo "[fatal] gocryptfs is not installed" >&2
  exit 1
}

mkdir -p "$SECRETS_DIR" "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"

GOCRYPTFS_PASSPHRASE_PATH="${SECRETS_DIR}/gocryptfs.key"
GOCRYPTFS_CONFIG_PATH="${GOCRYPTFS_CIPHERDIR}/gocryptfs.conf"

# First boot: generate gocryptfs passphrase.
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

if [ "$RESTIC_ENABLED" = "true" ]; then

  # Ensure restic binary exists.
  command -v restic >/dev/null 2>&1 || {
    echo "[fatal] restic is not installed" >&2
    exit 1
  }

  RESTIC_KEY_PATH="${SECRETS_DIR}/restic.key"
  mkdir -p "$SECRETS_DIR"

  # First boot: generate restic key once.
  if [ ! -s "$RESTIC_KEY_PATH" ]; then
    # Head may terminate the pipe early; ignore the resulting SIGPIPE-related non-zero exit.
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$GOCRYPTFS_PASSPHRASE_LENGTH" >"$RESTIC_KEY_PATH" || true

    if [ -s "$RESTIC_KEY_PATH" ]; then
      chmod 600 "$RESTIC_KEY_PATH"
      echo "[restic] key generated: $RESTIC_KEY_PATH"
    else
      echo "[fatal] failed to generate restic key: $RESTIC_KEY_PATH" >&2
      exit 1
    fi
  fi

  if [ ! -s "$RESTIC_KEY_PATH" ]; then
    echo "[fatal] restic key file is missing or empty: $RESTIC_KEY_PATH" >&2
    exit 1
  fi

  # Ensure repository directory exists for local filesystem backend.
  # If RESTIC_REPOSITORY is later changed to a remote backend (sftp, s3, etc.),
  # this line must be removed.
  mkdir -p "$RESTIC_REPOSITORY"

  # Initialize repository exactly once.
  # "restic cat config" is used as a generic repository access check.
  # If it fails, initialization is attempted.
  if ! restic --repo "$RESTIC_REPOSITORY" --password-file "$RESTIC_KEY_PATH" cat config >/dev/null 2>&1; then
    restic --repo "$RESTIC_REPOSITORY" --password-file "$RESTIC_KEY_PATH" init
    echo "[restic] initialized: $RESTIC_REPOSITORY"
  fi
fi

# Select uvicorn binary.
if [ -x /opt/hidden/.venv/bin/uvicorn ]; then
  UVICORN_BIN=/opt/hidden/.venv/bin/uvicorn
else
  UVICORN_BIN=uvicorn
fi

# Make uvicorn PID 1 so it receives signals directly.
exec "$UVICORN_BIN" app.main:app \
  --host "$UVICORN_HOST" \
  --port "$UVICORN_PORT" \
  --workers 1
