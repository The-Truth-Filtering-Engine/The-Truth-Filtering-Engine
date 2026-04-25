from dotenv import load_dotenv  
load_dotenv() 

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware 
from routers import search


app = FastAPI(title="진실의 입 API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(search.router, prefix="/api")