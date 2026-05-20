"""
CIRO+ Backend — Main Application Entry Point
Crisis Intelligence & Response Orchestrator Plus
"""

import logging
from fastapi import FastAPI
from app.api.endpoints import (
    health, signals, incidents, forecasts, actions,
    verification, resources, logs, knowledge_base, tracking
)
from fastapi.staticfiles import StaticFiles
from app.database import engine, Base, SessionLocal
from app.services.knowledge_base_service import populate_initial_kb

# ── Logging ────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(name)-30s │ %(levelname)-7s │ %(message)s",
)
logger = logging.getLogger("ciro")

# ── DB bootstrap ───────────────────────────────────────────────────────
Base.metadata.create_all(bind=engine)

db = SessionLocal()
try:
    populate_initial_kb(db)
finally:
    db.close()

# ── FastAPI app ────────────────────────────────────────────────────────
app = FastAPI(
    title="CIRO+ Backend",
    description=(
        "Backend for Crisis Intelligence & Response Orchestrator Plus. "
        "Ingests multi-source signals, detects crises, forecasts evolution, "
        "verifies reports, recommends precautions, simulates outcomes, and "
        "coordinates response via a 14-agent LLM pipeline (Gemini)."
    ),
    version="2.0.0",
)

# ── Routers ────────────────────────────────────────────────────────────
app.include_router(health.router,          prefix="/health",        tags=["System"])
app.include_router(signals.router,         prefix="/signals",       tags=["Signal Intake"])
app.include_router(incidents.router,       prefix="",               tags=["Incidents & Situations"])
app.include_router(forecasts.router,       prefix="",               tags=["Forecasts & Precautions"])
app.include_router(actions.router,         prefix="/actions",       tags=["Actions & Simulation"])
app.include_router(verification.router,    prefix="/verification",  tags=["Verification & Reports"])
app.include_router(resources.router,       prefix="/resources",     tags=["Resource Management"])
app.include_router(logs.router,            prefix="/logs",          tags=["Audit & Trace Logs"])
app.include_router(knowledge_base.router,  prefix="/kb",            tags=["Knowledge Base"])
app.include_router(tracking.router,        prefix="/tracking",      tags=["Family Tracking"])

# Mount static files for Frontend Dashboard
import os
static_dir = os.path.join(os.path.dirname(__file__), "static")
if not os.path.exists(static_dir):
    os.makedirs(static_dir)
app.mount("/dashboard", StaticFiles(directory=static_dir, html=True), name="static")


@app.get("/")
def root():
    return {
        "service": "CIRO+ Backend",
        "version": "2.0.0",
        "docs": "/docs",
        "status": "operational",
    }


@app.get("/version")
def version():
    return {"version": "2.0.0"}


@app.get("/system/status")
def system_status():
    return {
        "status": "operational",
        "agents": "14 Gemini-powered agents active",
        "services": {
            "database": "PostgreSQL + PostGIS",
            "cache": "Redis",
            "streaming": "Redis Streams",
            "orchestrator": "Antigravity (Gemini)",
        },
    }
