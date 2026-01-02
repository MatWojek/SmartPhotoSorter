import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.photos.routes import router as photos_router
from app.auth.routes import router as auth_router
from app.persons.routes import router as persons_router
from app.routes.services import router as services_router
from app.ml.routes import router as ml_router

IS_DEV = os.getenv("ENV", "dev") == "dev"

app = FastAPI(
    title="SmartPhotoSorter Cloud Minimal API", 
    docs_url="/swagger" if IS_DEV else None, 
    redoc_url="/redoc" if IS_DEV else None,
    openapi_url="/openapi.json" if IS_DEV else None 
)

# CORS (important if flutter is on another port)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers register
app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(photos_router, prefix="/photos", tags=["photos"])
app.include_router(persons_router, prefix="/persons", tags=["persons"])
app.include_router(services_router, prefix="/services", tags=["services"])
app.include_router(ml_router)

@app.get("/")
def root():
    return {"message": "SmartPhotoSorter API is working!"}
