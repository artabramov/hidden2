# app/main.py

from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends
from app.config import config
from sqlalchemy.ext.asyncio import AsyncSession
from app.db import init_db
from app.dependencies import get_orm_repository
from app.repositories.orm_repository import ORMRepository
from app.models.folder import Folder
from app.models.user import User

from app.logging import init_logging
from starlette.middleware.gzip import GZipMiddleware
from fastapi.middleware.cors import CORSMiddleware
from app.middleware.request_log_middleware import request_log_middleware
from app.middleware.request_uuid_middleware import request_uuid_middleware



@asynccontextmanager
async def lifespan(app: FastAPI):
    init_logging()
    await init_db()
    yield


app = FastAPI(
    title="hidden",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware)
app.middleware("http")(request_log_middleware)
app.middleware("http")(request_uuid_middleware)


@app.get("/")
async def root(
    orm_repo: ORMRepository = Depends(get_orm_repository),
):
    user = User(email="email20@noreply.no", name="name20")
    await orm_repo.insert(user, commit=True)
    selected_user = await orm_repo.select(User, name="name5")
    return {"app": "hidden", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "ok"}
