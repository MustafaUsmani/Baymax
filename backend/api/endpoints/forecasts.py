"""CIRO+ Forecast & Precaution Endpoints — real DB + agent pipeline."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.db_models import Incident, Forecast
from app.workflows.incident_response_workflow import run_forecast_only

router = APIRouter()


@router.get("/forecast/{incident_id}")
def get_forecast(incident_id: int, db: Session = Depends(get_db)):
    # Check for stored forecast first
    stored = db.query(Forecast).filter(Forecast.incident_id == incident_id).order_by(Forecast.created_at.desc()).first()
    if stored:
        return {
            "id": stored.id,
            "incident_id": stored.incident_id,
            "forecast_type": stored.forecast_type,
            "predicted_severity": stored.predicted_severity,
            "predicted_spread": stored.predicted_spread,
            "predicted_duration": stored.predicted_duration,
            "uncertainty_band": stored.uncertainty_band,
            "precaution_recommendations": stored.precaution_recommendations,
            "created_at": stored.created_at.isoformat(),
        }

    # Otherwise, run forecast agent on the fly
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    result = run_forecast_only(
        {
            "crisis_type": incident.crisis_type,
            "severity": incident.severity,
            "location": incident.location_text,
            "summary": incident.forecast_summary or "",
        },
        db=db,
    )

    # Persist the forecast
    new_forecast = Forecast(
        incident_id=incident_id,
        forecast_type=incident.crisis_type,
        predicted_severity=result.get("predicted_severity", "unknown"),
        predicted_spread=result.get("predicted_spread_km", 0.0),
        predicted_duration=int(result.get("predicted_duration_hours", 0) * 60),
        uncertainty_band=result.get("confidence_band", "unknown"),
        precaution_recommendations=result.get("precautions", []),
    )
    db.add(new_forecast)
    db.commit()
    db.refresh(new_forecast)

    return {
        "id": new_forecast.id,
        "incident_id": incident_id,
        "forecast_type": new_forecast.forecast_type,
        "predicted_severity": new_forecast.predicted_severity,
        "predicted_spread": new_forecast.predicted_spread,
        "predicted_duration": new_forecast.predicted_duration,
        "uncertainty_band": new_forecast.uncertainty_band,
        "precaution_recommendations": new_forecast.precaution_recommendations,
        "created_at": new_forecast.created_at.isoformat(),
        "agent_output": result,
    }


@router.get("/precautions/{incident_id}")
def get_precautions(incident_id: int, db: Session = Depends(get_db)):
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    # Run precaution agent
    from app.agents.agents import PrecautionAgent

    agent = PrecautionAgent()
    result = agent.execute({
        "crisis_type": incident.crisis_type,
        "severity": incident.severity,
        "location": incident.location_text,
        "predicted_spread_km": incident.affected_radius_m / 1000 if incident.affected_radius_m else 1,
        "predicted_duration_hours": incident.expected_duration_min / 60 if incident.expected_duration_min else 1,
        "escalation_probability": 0.5,
        "cascade_risks": [],
    })
    return {"incident_id": incident_id, **result}


@router.get("/risk/location")
def get_location_risk(lat: float, lon: float, destination: str = None, db: Session = Depends(get_db)):
    """Assess risk for a location/destination using the agent pipeline."""
    from app.agents.agents import ForecastingAgent, PrecautionAgent, TriggerRecommendationAgent
    from app.agents.orchestrator import orchestrator

    input_data = {
        "location": destination or f"{lat},{lon}",
        "location_lat": lat,
        "location_lng": lon,
        "crisis_type": "route_risk_assessment",
        "severity": "unknown",
        "summary": f"Route risk check for ({lat},{lon}) → {destination}",
    }

    result = orchestrator.run_sequential(
        agents=[ForecastingAgent(), PrecautionAgent(), TriggerRecommendationAgent()],
        initial_input=input_data,
        db=db,
    )
    return {"lat": lat, "lon": lon, "destination": destination, **result}
