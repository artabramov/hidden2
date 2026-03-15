from uuid import uuid4

from app.models.user import User
from app.repositories.orm import ORMRepository
from app.schemas.user_register import UserRegisterRequest
from app.security.encryption import encrypt_string
from app.security.hashing import hash_password
from app.security.jti import generate_jti
from app.security.totp import generate_totp_secret
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
