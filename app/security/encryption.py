# app/security/encryption.py

from cryptography.fernet import Fernet

from app.config import config


_fernet = Fernet(config.FERNET_KEY.encode())


def encrypt_string(value: str) -> str:
    return _fernet.encrypt(value.encode()).decode()


def decrypt_string(value: str) -> str:
    return _fernet.decrypt(value.encode()).decode()
