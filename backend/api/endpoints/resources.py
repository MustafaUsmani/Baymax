"""CIRO+ Resource Management Endpoints — real DB."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.db_models import Resource

router = APIRouter()


@router.get("/")
def get_resources(status: str = None, resource_type: str = None, db: Session = Depends(get_db)):
    q = db.query(Resource)
    if status:
        q = q.filter(Resource.status == status)
    if resource_type:
        q = q.filter(Resource.resource_type == resource_type)
    resources = q.all()
    return [
        {
            "id": r.id,
            "resource_type": r.resource_type,
            "status": r.status,
            "available_count": r.available_count,
            "last_assigned_incident": r.last_assigned_incident,
            "metadata": r.metadata_json,
        }
        for r in resources
    ]


@router.post("/allocate")
def allocate_resources(incident_id: int, resource_type: str, count: int, db: Session = Depends(get_db)):
    """Use the ResourceAllocator agent to plan allocation, then persist."""
    from app.agents.agents import ResourceAllocatorAgent
    from app.models.db_models import Incident

    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    agent = ResourceAllocatorAgent()
    result = agent.execute({
        "crisis_type": incident.crisis_type,
        "severity": incident.severity,
        "location": incident.location_text,
        "primary_plan": [],
        "affected_radius_km": incident.affected_radius_m / 1000 if incident.affected_radius_m else 1,
        "affected_population_estimate": "unknown",
    })

    # Upsert resource record
    resource = db.query(Resource).filter(
        Resource.resource_type == resource_type,
        Resource.status == "available",
    ).first()

    if resource:
        resource.available_count = max(0, resource.available_count - count)
        resource.last_assigned_incident = incident_id
        resource.status = "deployed" if resource.available_count == 0 else "available"
    else:
        resource = Resource(
            resource_type=resource_type,
            status="deployed",
            available_count=0,
            last_assigned_incident=incident_id,
            metadata_json={"agent_allocation": result},
        )
        db.add(resource)

    db.commit()
    return {
        "status": "allocated",
        "incident_id": incident_id,
        "resource_type": resource_type,
        "count": count,
        "agent_output": result,
    }


@router.post("/update-status")
def update_resource_status(resource_id: int, status: str, db: Session = Depends(get_db)):
    resource = db.query(Resource).filter(Resource.id == resource_id).first()
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    resource.status = status
    db.commit()
    return {"resource_id": resource_id, "new_status": status}
