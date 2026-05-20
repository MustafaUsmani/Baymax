"""CIRO+ Signal Intake Endpoints — real API ingestors + full agent pipeline."""

from fastapi import APIRouter, Depends, BackgroundTasks
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.schemas import SignalCreate, HumanReportCreate
from app.services.signal_ingestion import ingest_and_process_signal, ingest_and_process_human_report

router = APIRouter()


# ── Individual signal ingestion (runs full 14-agent pipeline) ─────────

@router.post("/social")
def ingest_social(signal: SignalCreate, db: Session = Depends(get_db)):
    signal.source_type = signal.source_type or "twitter"
    result = ingest_and_process_signal(signal, db)
    return {"status": "processed", "type": "social", "workflow_result": result}


@router.post("/human-report")
def ingest_human_report(report: HumanReportCreate, db: Session = Depends(get_db)):
    result = ingest_and_process_human_report(report, db)
    return {"status": "processed", "workflow_result": result}


@router.post("/weather")
def ingest_weather(signal: SignalCreate, db: Session = Depends(get_db)):
    signal.source_type = "weather_api"
    result = ingest_and_process_signal(signal, db)
    return {"status": "processed", "type": "weather", "workflow_result": result}


@router.post("/traffic")
def ingest_traffic(signal: SignalCreate, db: Session = Depends(get_db)):
    signal.source_type = "traffic_api"
    result = ingest_and_process_signal(signal, db)
    return {"status": "processed", "type": "traffic", "workflow_result": result}


@router.post("/economic")
def ingest_economic(signal: SignalCreate, db: Session = Depends(get_db)):
    signal.source_type = "economic_api"
    result = ingest_and_process_signal(signal, db)
    return {"status": "processed", "type": "economic", "workflow_result": result}


@router.post("/geopolitical")
def ingest_geopolitical(signal: SignalCreate, db: Session = Depends(get_db)):
    signal.source_type = "gdelt"
    result = ingest_and_process_signal(signal, db)
    return {"status": "processed", "type": "geopolitical", "workflow_result": result}


@router.post("/sensor")
def ingest_sensor(signal: SignalCreate, db: Session = Depends(get_db)):
    signal.source_type = "sensor"
    result = ingest_and_process_signal(signal, db)
    return {"status": "processed", "type": "sensor", "workflow_result": result}


# ── Batch ingestion from real APIs ────────────────────────────────────

@router.post("/fetch/all")
def fetch_all_sources(background_tasks: BackgroundTasks):
    """Trigger a full ingestion cycle across ALL real data sources (runs in background)."""
    from app.services.ingestion_service.master_ingestor import run_full_ingestion_cycle
    background_tasks.add_task(run_full_ingestion_cycle)
    return {"status": "ingestion_started", "message": "Full ingestion cycle running in background."}


@router.post("/fetch/social")
def fetch_social_sources():
    """Fetch latest data from Reddit, NewsAPI, GDELT, Google News RSS."""
    from app.services.ingestion_service.social_ingestor import fetch_all_social_sources
    events = fetch_all_social_sources()
    return {"status": "ok", "events_ingested": len(events)}


@router.post("/fetch/weather")
def fetch_weather_sources():
    """Fetch latest data from OpenWeatherMap and WeatherAPI."""
    from app.services.ingestion_service.weather_ingestor import fetch_all_weather
    events = fetch_all_weather()
    return {"status": "ok", "events_ingested": len(events)}


@router.post("/fetch/traffic")
def fetch_traffic_sources():
    """Fetch latest data from TomTom Traffic."""
    from app.services.ingestion_service.traffic_ingestor import fetch_all_traffic
    events = fetch_all_traffic()
    return {"status": "ok", "events_ingested": len(events)}


@router.post("/fetch/economic")
def fetch_economic_sources():
    """Fetch exchange rates, World Bank inflation, fuel prices."""
    from app.services.ingestion_service.economic_ingestor import fetch_all_economic
    events = fetch_all_economic()
    return {"status": "ok", "events_ingested": len(events)}


@router.post("/fetch/geopolitical")
def fetch_geopolitical_sources():
    """Fetch geopolitical data from GDELT DOC + GEO APIs."""
    from app.services.ingestion_service.geopolitics_ingestor import fetch_all_geopolitical
    events = fetch_all_geopolitical()
    return {"status": "ok", "events_ingested": len(events)}


@router.post("/fetch/iot")
def fetch_iot_sources():
    """Fetch from OpenAQ + mock water/power sensors."""
    from app.services.ingestion_service.iot_sensor_ingestor import fetch_all_iot_sensors
    events = fetch_all_iot_sensors()
    return {"status": "ok", "events_ingested": len(events)}


@router.post("/fetch/emergency-mock")
def fetch_emergency_mock(count: int = 10):
    """Generate synthetic 1122 emergency call logs."""
    from app.services.ingestion_service.emergency_mock_generator import generate_emergency_batch
    events = generate_emergency_batch(count=count)
    return {"status": "ok", "events_generated": len(events)}
