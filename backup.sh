#!/bin/sh
set -eu

echo "[restic] backup job started"

set -a
. /etc/hidden/.env
set +a

RESTIC_KEY_PATH="${SECRETS_DIR}/restic.key"

restic --repo "$RESTIC_REPOSITORY" --password-file "$RESTIC_KEY_PATH" \
  backup "$GOCRYPTFS_CIPHERDIR"

echo "[restic] prune started"

restic --repo "$RESTIC_REPOSITORY" --password-file "$RESTIC_KEY_PATH" \
  forget $RESTIC_FORGET_ARGS --prune

echo "[restic] backup job finished"
