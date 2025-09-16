import asyncio
import os
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.base import BaseHTTPMiddleware
from app.worker import start_worker
from app.models import initialize_models
from app.logger import setup_logging, log_startup, log_shutdown, log_api_request, get_logger

# Initialize structured logging
setup_logging()
logger = get_logger("main")

# Logging middleware for API requests
class LoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()

        response = await call_next(request)

        duration_ms = int((time.time() - start_time) * 1000)

        log_api_request(
            method=request.method,
            path=str(request.url.path),
            status_code=response.status_code,
            duration_ms=duration_ms,
            client_ip=request.client.host if request.client else None,
            user_agent=request.headers.get("user-agent"),
            request_id=response.headers.get("x-request-id")
        )

        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Log startup
    version = os.getenv("APP_VERSION", "1.0.0")
    config = {
        "port": 8001,
        "log_level": os.getenv("LOG_LEVEL", "INFO"),
        "workers": os.getenv("NLP_WORKERS", "2"),
    }
    log_startup("nlp", version, config)

    # Initialize models
    start = time.time()
    await initialize_models()
    logger.info("Models initialized", duration_ms=int((time.time() - start) * 1000))

    # Start worker in background
    worker_task = asyncio.create_task(start_worker())
    logger.info("NLP worker started")

    yield

    # Shutdown
    log_shutdown("nlp", "application_shutdown")
    worker_task.cancel()
    try:
        await worker_task
    except asyncio.CancelledError:
        pass


app = FastAPI(
    title="Content Warning Scanner - NLP Service",
    description="Natural Language Processing service for content analysis",
    version="1.0.0",
    lifespan=lifespan
)

# Add logging middleware
app.add_middleware(LoggingMiddleware)


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "nlp-worker"}


@app.get("/models")
async def list_models():
    from app.models import get_loaded_models
    return {"models": get_loaded_models()}


if __name__ == "__main__":
    import uvicorn

    # Configure uvicorn logging to use our structured logger
    config = uvicorn.Config(
        app,
        host="0.0.0.0",
        port=8001,
        log_config=None,  # Disable uvicorn's default logging
        access_log=False  # We handle access logs via middleware
    )
    server = uvicorn.Server(config)
    server.run()