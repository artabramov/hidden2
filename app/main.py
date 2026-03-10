from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends
from app.config import config
from sqlalchemy.ext.asyncio import AsyncSession
from app.db import init_db
from app.dependencies import get_orm_repository
from app.repositories.orm_repository import ORMRepository
from app.models.folder import Folder
from app.models.user import User


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(
    title="hidden",
    lifespan=lifespan,
)


@app.get("/")
async def root(
    orm_repo: ORMRepository = Depends(get_orm_repository),
):
    user = User(email="email1@noreply.no", name="name1")
    await orm_repo.insert(user, commit=True)
    selected_user = await orm_repo.select(User, name="name1")
    return {"app": "hidden", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "ok"}
