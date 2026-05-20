import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.endpoints import actions

# Initialize logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s │ %(levelname)s │ %(message)s")
logger = logging.getLogger("ciro")

# Create FastAPI app
app = FastAPI(
    title="CIRO+ Backend",
    description="Backend for Crisis Intelligence & Response Orchestrator Plus.",
    version="2.0.0",
)

# Add permissive CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(actions.router, prefix="/actions", tags=["Actions & Simulation"])

# Health endpoint
@app.get("/health")
def health_check():
    return {"status": "ok", "service": "CIRO+ Backend", "version": "2.0.0"}

# Root endpoint
@app.get("/")
def root():
    return {"service": "CIRO+ Backend", "version": "2.0.0", "docs": "/docs", "status": "operational"}
