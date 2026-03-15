from uuid import uuid4

import pyotp

from app.models.user import User
from app.repositories.orm import ORMRepository
from app.schemas.user import UserRegisterRequest
from app.security.encryption import encrypt_string
from app.security.password import hash_password
from app.errors import UsernameAlreadyExistsError


async def register_user(
    repository: ORMRepository,
    data: UserRegisterRequest,
) -> tuple[User, str]:
    existing_user = await repository.select(
        User, username=data.username,
    )

    if existing_user is not None:
        raise UsernameAlreadyExistsError

    totp_secret = pyotp.random_base32()
    current_jti = str(uuid4())

    user = User(
        username=data.username,
        password_hash=hash_password(data.password),
        first_name=data.first_name,
        last_name=data.last_name,
        summary=data.summary,
        totp_secret_encrypted=encrypt_string(totp_secret),
        current_jti_encrypted=encrypt_string(current_jti),
    )

    await repository.insert(user, flush=True, commit=True)
    return user, totp_secret
