from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.photos.routes import router as photos_router
from app.auth.routes import router as auth_router

app = FastAPI(title="SmartPhotoSorter Cloud Minimal API")

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

@app.get("/")
def root():
    return {"message": "SmartPhotoSorter API is working!"}
