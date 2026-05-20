"""CIRO+ Incident & Situation Endpoints — real PostGIS queries."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from geoalchemy2.elements import WKTElement
from geoalchemy2.functions import ST_DWithin, ST_GeogFromWKB

from app.database import get_db
from app.models.db_models import Incident, Signal

router = APIRouter()


def _incident_to_dict(inc: Incident) -> dict:
    return {
        "id": inc.id,
        "crisis_type": inc.crisis_type,
        "title": inc.title,
        "location_text": inc.location_text,
        "severity": inc.severity,
        "confidence": inc.confidence,
        "status": inc.status,
        "first_detected_at": inc.first_detected_at.isoformat() if inc.first_detected_at else None,
        "updated_at": inc.updated_at.isoformat() if inc.updated_at else None,
        "affected_radius_m": inc.affected_radius_m,
        "expected_duration_min": inc.expected_duration_min,
        "forecast_summary": inc.forecast_summary,
        "precaution_summary": inc.precaution_summary,
    }


@router.get("/incidents")
def get_incidents(status: str = None, crisis_type: str = None, db: Session = Depends(get_db)):
    q = db.query(Incident)
    if status:
        q = q.filter(Incident.status == status)
    if crisis_type:
        q = q.filter(Incident.crisis_type == crisis_type)
    q = q.order_by(Incident.first_detected_at.desc())
    return [_incident_to_dict(i) for i in q.limit(100).all()]


@router.get("/incidents/{incident_id}")
def get_incident(incident_id: int, db: Session = Depends(get_db)):
    inc = db.query(Incident).filter(Incident.id == incident_id).first()
    if not inc:
        raise HTTPException(status_code=404, detail="Incident not found")

    data = _incident_to_dict(inc)
    # Attach signals
    signals = db.query(Signal).filter(Signal.incident_id == incident_id).all()
    data["signals"] = [
        {
            "id": s.id,
            "source_type": s.source_type,
            "raw_text": s.raw_text,
            "credibility_score": s.credibility_score,
            "verification_status": s.verification_status,
            "timestamp": s.timestamp.isoformat() if s.timestamp else None,
        }
        for s in signals
    ]
    return data


@router.get("/incidents/nearby")
def get_nearby_incidents(lat: float, lon: float, radius: float = 5000, db: Session = Depends(get_db)):
    """Find active incidents within `radius` metres of a point using PostGIS."""
    point = WKTElement(f"POINT({lon} {lat})", srid=4326)
    incidents = (
        db.query(Incident)
        .filter(Incident.status == "active")
        .filter(ST_DWithin(Incident.location.cast_to("geography"), func.ST_GeogFromWKB(point.as_ewkb()), radius))
        .all()
    )
    return [_incident_to_dict(i) for i in incidents]


@router.get("/situations/current")
def get_current_situations(db: Session = Depends(get_db)):
    active = db.query(Incident).filter(Incident.status == "active").order_by(Incident.severity.desc()).all()
    return {
        "active_count": len(active),
        "incidents": [_incident_to_dict(i) for i in active],
    }


@router.get("/situations/forecast")
def get_situation_forecast(location: str, db: Session = Depends(get_db)):
    from app.workflows.incident_response_workflow import run_forecast_only

    result = run_forecast_only(
        {"location": location, "crisis_type": "general", "severity": "unknown", "summary": f"Forecast request for {location}"},
        db=db,
    )
    return result
