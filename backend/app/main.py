"""AI Heritage Reconstructor - FastAPI application entry point.

Run from the ``backend`` folder:
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
"""
from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException

from .config import get_settings
from .routers import assets, damage, health, identify, monuments


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="AI Heritage Reconstructor API",
        version="1.0.0",
        description=(
            "Backend for the AI Heritage Reconstructor Android app. "
            "Damage analysis is an OpenCV heuristic (possible indicators only). "
            "Reconstructions and 3D models are curated, hand-prepared assets."
        ),
    )

    # CORS: only needed for browser clients (Swagger UI / Flutter web).  The Android
    # app is not affected.  Origins are restricted by default; see backend/README.md.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_origins),
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )

    app.include_router(health.router)
    app.include_router(monuments.router)
    app.include_router(identify.router)
    app.include_router(damage.router)
    app.include_router(assets.router)

    (settings.static_dir / "images").mkdir(parents=True, exist_ok=True)
    (settings.static_dir / "models").mkdir(parents=True, exist_ok=True)
    app.mount("/static", StaticFiles(directory=settings.static_dir), name="static")

    web_dir = settings.static_dir.parent.parent / "mobile_app" / "build" / "web"
    if web_dir.exists():
        app.mount("/app", StaticFiles(directory=web_dir, html=True), name="web_app")

    # ---- consistent {"detail": "..."} error shape ------------------------------------
    @app.exception_handler(StarletteHTTPException)
    async def http_exc_handler(_: Request, exc: StarletteHTTPException):
        detail = exc.detail if isinstance(exc.detail, str) else "Request failed."
        return JSONResponse(status_code=exc.status_code, content={"detail": detail})

    @app.exception_handler(RequestValidationError)
    async def validation_handler(_: Request, exc: RequestValidationError):
        missing_file = any(e.get("loc", [None])[-1] == "file" for e in exc.errors())
        detail = (
            "No image was uploaded. Send the photograph as multipart/form-data in a field named 'file'."
            if missing_file
            else "The request was invalid."
        )
        return JSONResponse(status_code=422, content={"detail": detail})

    @app.exception_handler(Exception)
    async def unhandled_handler(_: Request, exc: Exception):
        return JSONResponse(status_code=500, content={"detail": "Internal server error."})

    return app


app = create_app()
