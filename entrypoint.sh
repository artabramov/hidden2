#!/bin/sh
set -eu
umask 077

ENV_DIR=/etc/hidden
ENV_PATH="$ENV_DIR/.env"

# Create .env file on first run.
mkdir -p "$ENV_DIR"
if [ ! -f "$ENV_PATH" ]; then
  cp /opt/hidden/.env.example "$ENV_PATH"
  chmod 600 "$ENV_PATH"
  echo "[hidden] created .env: $ENV_PATH"
fi

# Load environment variables.
set -a
. "$ENV_PATH"
set +a

# Validate environment variables.
: "${SECRETS_DIR:?SECRETS_DIR is not defined}"
: "${JWT_SIGNING_KEY_PATH:?JWT_SIGNING_KEY_PATH is not defined}"
: "${JWT_SIGNING_KEY_LENGTH:?JWT_SIGNING_KEY_LENGTH is not defined}"
: "${GOCRYPTFS_CIPHERDIR:?GOCRYPTFS_CIPHERDIR is not defined}"
: "${GOCRYPTFS_MOUNTPOINT:?GOCRYPTFS_MOUNTPOINT is not defined}"
: "${GOCRYPTFS_PASSPHRASE_LENGTH:?GOCRYPTFS_PASSPHRASE_LENGTH is not defined}"
: "${GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS:?GOCRYPTFS_WATCHDOG_INTERVAL_SECONDS is not defined}"
: "${UVICORN_HOST:?UVICORN_HOST is not defined}"
: "${UVICORN_PORT:?UVICORN_PORT is not defined}"

: "${RESTIC_ENABLED:?RESTIC_ENABLED is not defined}"
if [ "$RESTIC_ENABLED" = 1 ]; then
  : "${RESTIC_PASSWORD_LENGTH:?RESTIC_PASSWORD_LENGTH is not defined}"
  : "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY is not defined}"
  : "${RESTIC_CRON_SCHEDULE:?RESTIC_CRON_SCHEDULE is not defined}"
  : "${RESTIC_FORGET_ARGS:?RESTIC_FORGET_ARGS is not defined}"
fi

# Gocryptfs: ensure required binary exists.
command -v gocryptfs >/dev/null 2>&1 || {
  echo "[fatal] gocryptfs is not installed" >&2
  exit 1
}

# Restic: ensure required binary exists.
if [ "$RESTIC_ENABLED" = 1 ]; then
  command -v restic >/dev/null 2>&1 || {
    echo "[fatal] restic is not installed" >&2
    exit 1
  }
fi

mkdir -p "$SECRETS_DIR"

# Gocryptfs: generate passphrase once.
GOCRYPTFS_PASSPHRASE_PATH="${SECRETS_DIR}/gocryptfs.key"
if [ ! -s "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$GOCRYPTFS_PASSPHRASE_LENGTH" \
    >"$GOCRYPTFS_PASSPHRASE_PATH" || true
  if [ -s "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
    chmod 600 "$GOCRYPTFS_PASSPHRASE_PATH"
    echo "[gocryptfs] passphrase generated: $GOCRYPTFS_PASSPHRASE_PATH"
  else
    echo "[fatal] failed to generate gocryptfs passphrase: $GOCRYPTFS_PASSPHRASE_PATH" >&2
    exit 1
  fi
fi

# Restic: generate password once.
if [ "$RESTIC_ENABLED" = 1 ]; then
  RESTIC_KEY_PATH="${SECRETS_DIR}/restic.key"
  if [ ! -s "$RESTIC_KEY_PATH" ]; then
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$RESTIC_PASSWORD_LENGTH" \
      >"$RESTIC_KEY_PATH" || true
    if [ -s "$RESTIC_KEY_PATH" ]; then
      chmod 600 "$RESTIC_KEY_PATH"
      echo "[restic] password generated: $RESTIC_KEY_PATH"
    else
      echo "[fatal] failed to generate restic password: $RESTIC_KEY_PATH" >&2
      exit 1
    fi
  fi
fi

# Gocryptfs: initialize cipherdir exactly once.
mkdir -p "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"
GOCRYPTFS_CONFIG_PATH="${GOCRYPTFS_CIPHERDIR}/gocryptfs.conf"
if [ ! -f "$GOCRYPTFS_CONFIG_PATH" ]; then
  # Suppress all init output because gocryptfs prints the master key.
  gocryptfs -nosyslog -init -passfile "$GOCRYPTFS_PASSPHRASE_PATH" \
    "$GOCRYPTFS_CIPHERDIR" >/dev/null 2>&1
  echo "[gocryptfs] initialized: $GOCRYPTFS_CIPHERDIR"
fi

# Gocryptfs: initial mount before application start.
if ! command -v mountpoint >/dev/null 2>&1 \
  || ! mountpoint -q "$GOCRYPTFS_MOUNTPOINT"
then
  gocryptfs -nosyslog -passfile "$GOCRYPTFS_PASSPHRASE_PATH" \
    "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT"
  echo "[gocryptfs] mounted: $GOCRYPTFS_MOUNTPOINT"
fi

# JWT: generate signing key once.
if [ ! -s "$JWT_SIGNING_KEY_PATH" ]; then
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$JWT_SIGNING_KEY_LENGTH" \
    >"$JWT_SIGNING_KEY_PATH" || true
  if [ -s "$JWT_SIGNING_KEY_PATH" ]; then
    chmod 600 "$JWT_SIGNING_KEY_PATH"
    echo "[jwt] signing key generated: $JWT_SIGNING_KEY_PATH"
  else
    echo "[fatal] failed to generate JWT signing key: $JWT_SIGNING_KEY_PATH" >&2
    exit 1
  fi
fi

# Create directories inside gocryptfs storage.
DB_DIR="$GOCRYPTFS_MOUNTPOINT/db"
FILES_DIR="$GOCRYPTFS_MOUNTPOINT/files"
mkdir -p "$DB_DIR" "$FILES_DIR"

# Restic: initialize repository exactly once.
if [ "$RESTIC_ENABLED" = 1 ]; then
  # This line must be removed if RESTIC_REPOSITORY
  # is changed to a remote backend (sftp, s3, etc.).
  mkdir -p "$RESTIC_REPOSITORY"

  # "restic cat config" is used as a generic repository access check.
  # If access fails, initialization is attempted.
  # On an already initialized repository, repeated "init" will fail
  # and the script will exit because "set -e" is enabled.
  if ! restic --repo "$RESTIC_REPOSITORY" --password-file "$RESTIC_KEY_PATH" \
    cat config >/dev/null 2>&1;
  then
    restic --repo "$RESTIC_REPOSITORY" --password-file "$RESTIC_KEY_PATH" init
    echo "[restic] initialized: $RESTIC_REPOSITORY"
  fi
fi

# Watchdog:
# - mount when passphrase exists and storage is not mounted
# - unmount when passphrase disappears
HAS_MOUNTPOINT=0
if command -v mountpoint >/dev/null 2>&1; then
  HAS_MOUNTPOINT=1
fi
(
  while :; do
    if [ -s "$GOCRYPTFS_PASSPHRASE_PATH" ]; then
      # Mount if key exists and storage is not mounted.
      if [ -f "$GOCRYPTFS_CONFIG_PATH" ] && \
         { [ "$HAS_MOUNTPOINT" = 0 ] || ! mountpoint -q "$GOCRYPTFS_MOUNTPOINT"; }
      then
        gocryptfs -nosyslog -passfile "$GOCRYPTFS_PASSPHRASE_PATH" \
          "$GOCRYPTFS_CIPHERDIR" "$GOCRYPTFS_MOUNTPOINT" >/dev/null 2>&1 \
          && echo "[watchdog] mounted: $GOCRYPTFS_MOUNTPOINT" || true
      fi
    else
      # Unmount if key disappeared and storage is mounted.
      if [ "$HAS_MOUNTPOINT" = 0 ] || mountpoint -q "$GOCRYPTFS_MOUNTPOINT"; then
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

# Configure restic cron job
crontab -r 2>/dev/null || true
if [ "${RESTIC_ENABLED}" = 1 ]; then
  echo "$RESTIC_CRON_SCHEDULE /opt/hidden/backup.sh >> /proc/1/fd/1 2>> /proc/1/fd/2" | crontab -
fi
cron

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
