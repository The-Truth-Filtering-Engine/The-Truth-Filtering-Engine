from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent  # .../The-Truth-Filtering-Engine
ENV_PATH = BASE_DIR / "the_truth_filtering_engine" / ".env"
load_dotenv(dotenv_path=ENV_PATH)

from fastapi import FastAPI
from routers import search
from fastapi.middleware.cors import CORSMiddleware 

app = FastAPI(title="진실의 입 API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(search.router, prefix="/api")

@app.get("/")
def root():
    return {"status": "ok"}