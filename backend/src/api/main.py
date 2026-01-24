"""Main FastAPI application."""

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.api.routes import auth, feedback, friends, places, sync

# Application metadata
app = FastAPI(
    title="Footprint API",
    description="API for Footprint travel tracking application",
    version="0.1.0",
    docs_url="/docs" if os.environ.get("ENVIRONMENT") != "prod" else None,
    redoc_url="/redoc" if os.environ.get("ENVIRONMENT") != "prod" else None,
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Include routers
app.include_router(auth.router)
app.include_router(places.router)
app.include_router(sync.router)
app.include_router(friends.router)
app.include_router(feedback.router)


@app.get("/")
async def root():
    """Root endpoint - health check."""
    return {
        "message": "Footprint API is running",
        "environment": os.environ.get("ENVIRONMENT", "unknown"),
        "version": "0.1.0",
    }


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "footprint-api"}
