from pydantic import BaseModel, ConfigDict, Field


class UserRegisterResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    id: int
    totp_secret: str = Field(
        min_length=16,
        max_length=255,
    )
