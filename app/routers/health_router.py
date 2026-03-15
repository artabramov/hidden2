import os

from fastapi import APIRouter
from app.config import config


router = APIRouter(tags=["health"])


@router.get("/health")
async def health():
    from app.security.encryption import encrypt_string, decrypt_string
    str_encrypted = encrypt_string("qwerty123")
    str_decrypted = decrypt_string(str_encrypted)
    
    key_path = os.path.join(config.SECRETS_DIR, "gocryptfs.key")

    gocryptfs_key_exists = os.path.isfile(key_path)
    gocryptfs_storage_mounted = os.path.ismount(config.GOCRYPTFS_MOUNTPOINT)

    return {
        "gocryptfs_key_exists": gocryptfs_key_exists,
        "gocryptfs_storage_mounted": gocryptfs_storage_mounted,
    }
