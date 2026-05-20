"""
CIRO+ Ingestion Service
Receives signals from API endpoints, publishes to Redis Streams,
and triggers the full 14-agent workflow pipeline.
"""

import logging
import uuid
from datetime import datetime
from typing import Dict, Any, Optional

from sqlalchemy.orm import Session
from geoalchemy2.elements import WKTElement

from app.models.schemas import SignalCreate, HumanReportCreate
from app.models.db_models import Signal, HumanReport, Incident, StandardEvent
from app.workflows.incident_response_workflow import run_incident_workflow, run_verification_only

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Source reliability baseline
# ---------------------------------------------------------------------------
SOURCE_RELIABILITY = {
    "1122_mock": 0.95,
    "weather_api": 0.92,
    "traffic_api": 0.85,
    "gdelt": 0.80,
    "news": 0.78,
    "economic_api": 0.90,
    "reddit": 0.50,
    "twitter": 0.45,
    "user_report": 0.40,
    "unknown": 0.30,
}


def _reliability(source: str) -> float:
    return SOURCE_RELIABILITY.get(source, 0.30)


# ---------------------------------------------------------------------------
# Signal ingestion  →  full pipeline
# ---------------------------------------------------------------------------
def ingest_and_process_signal(signal: SignalCreate, db: Session) -> Dict[str, Any]:
    """
    1. Persist the raw signal in the DB.
    2. Build a standard event dict.
    3. Run the full 14-agent workflow pipeline.
    4. If the pipeline detects a crisis, create / update an Incident.
    """
    logger.info(f"Ingesting signal from source={signal.source_name}")

    # ── 1. Persist raw signal ──────────────────────────────────────────
    db_signal = Signal(
        source_type=signal.source_type,
        source_name=signal.source_name,
        raw_text=signal.raw_text,
        language=signal.language,
        source_metadata=signal.source_metadata or {},
        verification_status="pending",
        credibility_score=_reliability(signal.source_type),
    )
    db.add(db_signal)
    db.commit()
    db.refresh(db_signal)

    # ── 2. Build standard event dict ───────────────────────────────────
    event_input: Dict[str, Any] = {
        "event_id": str(uuid.uuid4()),
        "source": signal.source_type,
        "raw_text": signal.raw_text,
        "timestamp": datetime.utcnow().isoformat(),
        "source_reliability": _reliability(signal.source_type),
        "signal_db_id": db_signal.id,
    }

    # ── 3. Run full pipeline ───────────────────────────────────────────
    result = run_incident_workflow(event_input, db=db)

    # ── 4. Create incident if crisis detected ──────────────────────────
    incident = _maybe_create_incident(result, db)
    if incident:
        # Link signal to incident
        db_signal.incident_id = incident.id
        db_signal.verification_status = result.get("verification_status", "unverified")
        db_signal.credibility_score = result.get("credibility_score", db_signal.credibility_score)
        db.commit()
        result["incident_id"] = incident.id

    return result


# ---------------------------------------------------------------------------
# Human report ingestion  →  verification pipeline
# ---------------------------------------------------------------------------
def ingest_and_process_human_report(report: HumanReportCreate, db: Session) -> Dict[str, Any]:
    """
    1. Persist the human report.
    2. Run verification-only pipeline.
    3. Update report status from pipeline output.
    """
    logger.info("Ingesting human report")

    lat = report.location.lat
    lon = report.location.lon

    db_report = HumanReport(
        user_id=report.user_id,
        text=report.text,
        location=WKTElement(f"POINT({lon} {lat})", srid=4326),
        attachment_url=report.attachment_url,
        report_status="pending",
        verified_by_agent=False,
        verification_score=0.0,
    )
    db.add(db_report)
    db.commit()
    db.refresh(db_report)

    # Build input for the pipeline
    event_input: Dict[str, Any] = {
        "event_id": str(uuid.uuid4()),
        "source": "user_report",
        "raw_text": report.text,
        "location": report.location.lat,  # kept for agent prompt
        "location_lat": lat,
        "location_lng": lon,
        "timestamp": datetime.utcnow().isoformat(),
        "source_reliability": _reliability("user_report"),
        "is_human_report": True,
        "report_db_id": db_report.id,
    }

    # Run full pipeline (not just verification) to get full analysis
    result = run_incident_workflow(event_input, db=db)

    # Update report record with verification results
    db_report.report_status = result.get("verification_status", "unverified")
    db_report.verified_by_agent = result.get("verification_status") in ("verified", "partially_verified")
    db_report.verification_score = result.get("credibility_score", 0.0)

    # Link to incident if created
    incident = _maybe_create_incident(result, db)
    if incident:
        db_report.incident_id = incident.id
        result["incident_id"] = incident.id

    db.commit()
    result["report_id"] = db_report.id
    return result


# ---------------------------------------------------------------------------
# Incident creation helper
# ---------------------------------------------------------------------------
def _maybe_create_incident(pipeline_result: Dict[str, Any], db: Session) -> Optional[Incident]:
    """Create a DB Incident if the pipeline detected a real crisis."""
    crisis_type = pipeline_result.get("crisis_type")
    if not crisis_type or crisis_type == "unknown":
        return None

    severity = pipeline_result.get("severity", "low")
    confidence = pipeline_result.get("confidence", 0.0)
    if confidence < 0.5:
        return None  # Not confident enough

    location_name = pipeline_result.get("location", "Unknown")
    lat = pipeline_result.get("location_lat", 0.0) or 0.0
    lng = pipeline_result.get("location_lng", 0.0) or 0.0
    summary = pipeline_result.get("summary", "")
    advisory = pipeline_result.get("general_advisory", "")

    incident = Incident(
        crisis_type=crisis_type,
        title=f"{crisis_type.replace('_', ' ').title()} — {location_name}",
        location=WKTElement(f"POINT({lng} {lat})", srid=4326),
        location_text=location_name,
        severity=severity,
        confidence=confidence,
        status="active",
        affected_radius_m=pipeline_result.get("affected_radius_km", 1.0) * 1000,
        expected_duration_min=int(pipeline_result.get("predicted_duration_hours", 1) * 60),
        forecast_summary=pipeline_result.get("reasoning", ""),
        precaution_summary=advisory,
    )
    db.add(incident)
    db.commit()
    db.refresh(incident)
    logger.info(f"Created Incident #{incident.id}: {incident.title}")
    return incident
