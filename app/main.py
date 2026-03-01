from fastapi import FastAPI

app = FastAPI(title="hidden")

@app.get("/")
def root():
    return {"app": "hidden", "status": "ok"}

@app.get("/health")
def health():
    return {"status": "ok"}
