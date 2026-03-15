from uuid import uuid4

import pyotp

from app.models.user import User
from app.repositories.orm_repository import ORMRepository
from app.schemas.user_register_request import UserRegisterRequest
from app.cryptography.data_encryption import encrypt_string
from app.cryptography.password_hash import hash_password
from app.cryptography.totp_validation import generate_totp_secret
from app.cryptography.jti_generation import generate_jti
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

    totp_secret = generate_totp_secret()
    current_jti = generate_jti()

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
