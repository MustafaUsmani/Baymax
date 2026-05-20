"""CIRO+ Audit & Trace Log Endpoints — real DB queries."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.db_models import AgentTrace, Action

router = APIRouter()


def _trace_to_dict(t: AgentTrace) -> dict:
    return {
        "id": t.id,
        "incident_id": t.incident_id,
        "agent_name": t.agent_name,
        "step_name": t.step_name,
        "step_type": t.step_type,
        "input_summary": t.input_summary,
        "decision_summary": t.decision_summary,
        "output_summary": t.output_summary,
        "confidence": t.confidence,
        "created_at": t.created_at.isoformat() if t.created_at else None,
    }


@router.get("/incidents/{incident_id}")
def get_incident_logs(incident_id: int, db: Session = Depends(get_db)):
    traces = (
        db.query(AgentTrace)
        .filter(AgentTrace.incident_id == incident_id)
        .order_by(AgentTrace.created_at.asc())
        .all()
    )
    return [_trace_to_dict(t) for t in traces]


@router.get("/actions/{action_id}")
def get_action_logs(action_id: int, db: Session = Depends(get_db)):
    action = db.query(Action).filter(Action.id == action_id).first()
    if not action:
        return []
    traces = (
        db.query(AgentTrace)
        .filter(AgentTrace.incident_id == action.incident_id)
        .order_by(AgentTrace.created_at.asc())
        .all()
    )
    return [_trace_to_dict(t) for t in traces]


@router.get("/agents/{agent_name}")
def get_agent_logs(agent_name: str, db: Session = Depends(get_db)):
    traces = (
        db.query(AgentTrace)
        .filter(AgentTrace.agent_name.ilike(f"%{agent_name}%"))
        .order_by(AgentTrace.created_at.desc())
        .limit(100)
        .all()
    )
    return [_trace_to_dict(t) for t in traces]


@router.get("/trace/{incident_id}")
def get_incident_trace(incident_id: int, db: Session = Depends(get_db)):
    """Full structured trace for an incident — used by the command center dashboard."""
    traces = (
        db.query(AgentTrace)
        .filter(AgentTrace.incident_id == incident_id)
        .order_by(AgentTrace.created_at.asc())
        .all()
    )
    return {
        "incident_id": incident_id,
        "total_steps": len(traces),
        "trace": [_trace_to_dict(t) for t in traces],
    }
