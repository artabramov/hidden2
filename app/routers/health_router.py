import os

from fastapi import APIRouter
from app.config import config


router = APIRouter(tags=["health"])


@router.get("/health")
async def health():
    key_path = os.path.join(config.SECRETS_DIR, "gocryptfs.key")

    key_exists = os.path.isfile(key_path)
    key_nonempty = key_exists and os.path.getsize(key_path) > 0
    storage_mounted = os.path.ismount(config.GOCRYPTFS_MOUNTPOINT)

    return {
        "gocryptfs_key_exists": key_exists,
        "gocryptfs_key_nonempty": key_nonempty,
        "gocryptfs_storage_mounted": storage_mounted,
    }
