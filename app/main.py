from fastapi import FastAPI
from app.config import settings

app = FastAPI(title="hidden")

@app.get("/")
def root():
    return {"app": "hidden", "status": "ok"}

@app.get("/health")
def health():
    return {"status": "ok"}
