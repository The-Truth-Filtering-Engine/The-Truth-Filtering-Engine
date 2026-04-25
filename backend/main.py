from pathlib import Path
from dotenv import load_dotenv  
load_dotenv(r"C:\Users\User\Desktop\Intel_AI_education\NLP_project\The-Truth-Filtering-Engine\the_truth_filtering_engine\.env")  

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