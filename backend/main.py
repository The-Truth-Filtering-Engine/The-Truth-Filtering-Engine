from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent  
load_dotenv(dotenv_path=BASE_DIR / ".env")  

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import search, places

app = FastAPI(title="진실의 입 API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(search.router, prefix="/api")
app.include_router(places.router)

@app.get("/")
def root():
    return {"status": "ok"}