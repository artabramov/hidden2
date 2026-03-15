import uuid


def generate_jti() -> str:
    return uuid.uuid4().hex
