from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic_core import PydanticCustomError


class UserRegisterRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
    )

    username: str = Field(min_length=3, max_length=40)
    password: str = Field(min_length=8)
    first_name: str = Field(min_length=1, max_length=40)
    last_name: str = Field(min_length=1, max_length=40)
    summary: str | None = Field(default=None, max_length=4096)

    @field_validator("username")
    @classmethod
    def validate_username(cls, value: str) -> str:
        allowed = set(
            "abcdefghijklmnopqrstuvwxyz"
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            "0123456789_"
        )
        if not all(char in allowed for char in value):
            raise PydanticCustomError(
                "invalid_characters",
                "Must contain only letters, digits, underscore.",
            )
        return value

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if not any(c.islower() for c in value):
            raise PydanticCustomError(
                "no_lowercase",
                "Password must contain at least one lowercase letter.",
            )

        if not any(c.isupper() for c in value):
            raise PydanticCustomError(
                "no_uppercase",
                "Password must contain at least one uppercase letter.",
            )

        if not any(c.isdigit() for c in value):
            raise PydanticCustomError(
                "no_digit",
                "Password must contain at least one digit.",
            )

        return value

    @field_validator("summary")
    @classmethod
    def normalize_summary(cls, value: str | None) -> str | None:
        if value == "":
            return None
        return value
