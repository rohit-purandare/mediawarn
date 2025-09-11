import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from app.worker import start_worker
from app.models import initialize_models

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting NLP service...")
    
    # Initialize models
    await initialize_models()
    
    # Start worker in background
    worker_task = asyncio.create_task(start_worker())
    
    yield
    
    # Shutdown
    logger.info("Shutting down NLP service...")
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

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "nlp-worker"}

@app.get("/models")
async def list_models():
    from app.models import get_loaded_models
    return {"models": get_loaded_models()}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)