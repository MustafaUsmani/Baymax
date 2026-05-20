from sqlalchemy.orm import Session
from app.models.db_models import StandardEvent, Incident
from geoalchemy2.elements import WKTElement
import logging

logger = logging.getLogger(__name__)

def normalize_and_deduplicate(event_data: dict, db: Session):
    """
    Checks if an incoming standard event clusters with an existing active incident.
    Boosts confidence if multiple sources confirm the same event.
    """
    event_type = event_data.get("event_type")
    lat = event_data.get("location", {}).get("lat", 0.0)
    lng = event_data.get("location", {}).get("lng", 0.0)
    reliability = event_data.get("source_reliability", 0.5)
    
    # Very basic PostGIS proximity check (mocked distance for simplicity in ORM without complex raw SQL here)
    # In a real scenario: ST_DWithin(Incident.location, WKTElement(f'POINT({lng} {lat})', srid=4326), 1000)
    
    nearby_incident = db.query(Incident).filter(
        Incident.crisis_type == event_type,
        Incident.status == "active"
    ).first()
    
    if nearby_incident:
        logger.info(f"Clustering event into existing incident {nearby_incident.id}")
        # Boost confidence formula: Current + (1 - Current) * Reliability * 0.5
        boost = (1 - nearby_incident.confidence) * reliability * 0.5
        nearby_incident.confidence = min(1.0, nearby_incident.confidence + boost)
        db.commit()
        return nearby_incident
    else:
        logger.info("No nearby incident found. Could create a new incident if reliability > threshold.")
        # Create new StandardEvent record
        db_event = StandardEvent(
            event_id=event_data["event_id"],
            source=event_data["source"],
            event_type=event_type,
            location_lat=lat,
            location_lng=lng,
            location_name=event_data["location"].get("name"),
            severity=event_data.get("severity", 0.0),
            confidence=event_data.get("confidence", 0.0),
            raw_text=event_data.get("raw_text", ""),
            structured_data=event_data.get("structured_data", {}),
            source_reliability=reliability
        )
        db.add(db_event)
        
        # If confidence > 0.6, promote to Incident
        if event_data.get("confidence", 0.0) > 0.6:
            new_incident = Incident(
                crisis_type=event_type,
                title=f"{event_type.capitalize()} at {event_data['location'].get('name')}",
                location=WKTElement(f'POINT({lng} {lat})', srid=4326),
                location_text=event_data['location'].get('name'),
                severity="medium",
                confidence=event_data.get("confidence", 0.0),
                status="active"
            )
            db.add(new_incident)
            db.commit()
            return new_incident
            
        db.commit()
        return None
