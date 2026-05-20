import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.endpoints import actions, forecasts, health, incidents, knowledge_base, logs, resources, signals, tracking, verification
from app.api.endpoints.forecasts import get_location_risk
from fastapi import Depends
from sqlalchemy.orm import Session
from app.database import get_db
# Router includes moved below after app creation

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
app.include_router(forecasts.router, prefix="/forecasts", tags=["Forecasts"])
app.include_router(incidents.router, prefix="/incidents", tags=["Incidents"])
app.include_router(knowledge_base.router, prefix="/knowledge", tags=["Knowledge Base"])
app.include_router(logs.router, prefix="/logs", tags=["Logs"])
app.include_router(resources.router, prefix="/resources", tags=["Resources"])
app.include_router(signals.router, prefix="/signals", tags=["Signals"])
app.include_router(tracking.router, prefix="/tracking", tags=["Tracking"])
app.include_router(verification.router, prefix="/verification", tags=["Verification"])

# Health endpoint
@app.get("/health")
def health_check():
    return {"status": "ok", "service": "CIRO+ Backend", "version": "2.0.0"}

# Root endpoint
@app.get("/")
def root():
    return {"service": "CIRO+ Backend", "version": "2.0.0", "docs": "/docs", "status": "operational"}
@app.get("/risk/location")
def risk_location(lat: float, lon: float, destination: str = None, db: Session = Depends(get_db)):
    """Proxy to forecasts risk endpoint."""
    return get_location_risk(lat=lat, lon=lon, destination=destination, db=db)
