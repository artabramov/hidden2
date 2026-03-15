from pydantic import BaseModel, ConfigDict, Field, field_validator


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
            "0123456789_-"
        )
        if not all(char in allowed for char in value):
            raise ValueError(
                "Username may contain only letters, digits, "
                "underscore, and hyphen."
            )
        return value

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if not any(c.islower() for c in value):
            raise ValueError(
                "Password must contain at least one lowercase letter."
            )

        if not any(c.isupper() for c in value):
            raise ValueError(
                "Password must contain at least one uppercase letter."
            )

        if not any(c.isdigit() for c in value):
            raise ValueError(
                "Password must contain at least one digit."
            )

        return value

    @field_validator("summary")
    @classmethod
    def normalize_summary(cls, value: str | None) -> str | None:
        if value == "":
            return None
        return value
