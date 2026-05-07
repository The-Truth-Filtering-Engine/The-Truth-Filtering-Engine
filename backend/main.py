from contextlib import asynccontextmanager
import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(dotenv_path=BASE_DIR / ".env")

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import search, places, ai_recommend, users
from services.electra_service import load_model


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 서버 시작 시 ELECTRA 모델 1회 로드
    load_model()
    yield
    # 서버 종료 시 필요한 정리 작업이 있으면 여기에 추가


app = FastAPI(title="진실의 입 API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(search.router, prefix="/api")
app.include_router(ai_recommend.router, prefix="/api")
app.include_router(users.router, prefix="/api")
app.include_router(places.router)


@app.get("/")
def root():
    return {"status": "ok"}


@app.get("/config")
def config():
    return {"kakaoJsKey": os.getenv("KAKAO_JS_KEY", "").strip()}
