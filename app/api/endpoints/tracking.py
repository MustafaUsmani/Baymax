from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from geoalchemy2.elements import WKTElement
import datetime

from app.database import get_db
from app.models.schemas import FamilyMemberCreate, FamilyMemberLocationUpdate, FamilyMemberResponse
from app.models.db_models import FamilyMember, Incident

router = APIRouter()

@router.post("/register", response_model=FamilyMemberResponse)
def register_family_member(member: FamilyMemberCreate, db: Session = Depends(get_db)):
    """Register a new family member for tracking."""
    db_member = FamilyMember(
        user_id=member.user_id,
        name=member.name,
        phone_number=member.phone_number,
        is_safe=True
    )
    db.add(db_member)
    db.commit()
    db.refresh(db_member)
    return db_member

@router.post("/location/{member_id}")
def update_location(member_id: int, location_update: FamilyMemberLocationUpdate, db: Session = Depends(get_db)):
    """Update GPS location of a family member."""
    member = db.query(FamilyMember).filter(FamilyMember.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Family member not found")

    point = f"POINT({location_update.location.lon} {location_update.location.lat})"
    member.last_known_location = WKTElement(point, srid=4326)
    member.last_updated_at = datetime.datetime.utcnow()
    
    db.commit()
    return {"status": "Location updated successfully"}

@router.get("/status/{member_id}", response_model=FamilyMemberResponse)
def check_safety_status(member_id: int, db: Session = Depends(get_db)):
    """Check if the family member is inside any active crisis zone."""
    member = db.query(FamilyMember).filter(FamilyMember.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Family member not found")

    if not member.last_known_location:
        return member

    # Use PostGIS ST_DWithin to check if member is within any active incident radius
    # ST_DWithin uses meters when geography/srid 4326 is used properly, 
    # but since our geometry is POINT 4326, we cast to geography for accurate meter distance.
    from sqlalchemy import func, text
    
    active_incidents = db.query(Incident).filter(
        Incident.status == "active",
        func.ST_DWithin(
            func.cast(member.last_known_location, type_=text("geography")),
            func.cast(Incident.location, type_=text("geography")),
            Incident.affected_radius_m
        )
    ).all()

    # Update safety status
    is_safe = len(active_incidents) == 0
    if member.is_safe != is_safe:
        member.is_safe = is_safe
        db.commit()

    # Append incident warnings if not safe
    response = FamilyMemberResponse.from_orm(member).dict()
    if not is_safe:
        response["warnings"] = [
            f"Proximity Alert: Near {inc.crisis_type} at {inc.location_text}"
            for inc in active_incidents
        ]
    
    return response

@router.get("/list/{user_id}")
def list_family_members(user_id: str, db: Session = Depends(get_db)):
    """List all tracked family members for a given user."""
    members = db.query(FamilyMember).filter(FamilyMember.user_id == user_id).all()
    return [FamilyMemberResponse.from_orm(m) for m in members]
