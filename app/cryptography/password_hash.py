import hashlib
import hmac
import os


_ITERATIONS = 600_000
_SALT_SIZE = 16
_ALGORITHM = "sha256"


def hash_password(password: str) -> str:
    salt = os.urandom(_SALT_SIZE)

    dk = hashlib.pbkdf2_hmac(
        _ALGORITHM,
        password.encode("utf-8"),
        salt,
        _ITERATIONS,
    )

    return f"{_ITERATIONS}${salt.hex()}${dk.hex()}"


def verify_password(password: str, password_hash: str) -> bool:
    try:
        iterations_str, salt_hex, hash_hex = password_hash.split("$", 2)
    except ValueError:
        return False

    iterations = int(iterations_str)
    salt = bytes.fromhex(salt_hex)
    expected = bytes.fromhex(hash_hex)

    dk = hashlib.pbkdf2_hmac(
        _ALGORITHM,
        password.encode("utf-8"),
        salt,
        iterations,
    )

    return hmac.compare_digest(dk, expected)
