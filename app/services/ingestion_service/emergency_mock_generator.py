from app.services.redis_streams import stream_client
import uuid
from datetime import datetime
import random
import time

def generate_emergency_mock():
    """
    Simulates a synthetic 1122/911 call log.
    Spike detection = crisis trigger.
    """
    incident_types = ["fire", "accident", "medical", "flood_rescue"]
    locations = ["Blue Area", "F-8 Markaz", "I-9 Industrial", "Faizabad"]
    
    while True:
        incident = random.choice(incident_types)
        loc = random.choice(locations)
        
        event = {
            "event_id": str(uuid.uuid4()),
            "source": "1122_mock",
            "event_type": incident,
            "location": {"lat": 33.6844, "lng": 73.0479, "name": loc}, # Static mock coords
            "timestamp": datetime.utcnow().isoformat(),
            "severity": round(random.uniform(0.6, 1.0), 2),
            "confidence": 0.95, # Official emergency line
            "raw_text": f"Emergency call received for {incident} at {loc}",
            "structured_data": {"caller_type": "citizen", "dispatched": True},
            "source_reliability": 0.95
        }
        
        stream_client.publish_event(event)
        time.sleep(random.randint(5, 15)) # Emit a mock event every 5-15 seconds


def generate_emergency_batch(count: int = 5) -> list:
    """Generate a batch of emergency events (non-blocking)."""
    incident_types = ["fire", "accident", "medical", "flood_rescue", "gas_leak", "building_collapse"]
    locations = [
        {"name": "Blue Area", "lat": 33.7100, "lng": 73.0580},
        {"name": "F-8 Markaz", "lat": 33.7060, "lng": 73.0380},
        {"name": "I-9 Industrial", "lat": 33.6500, "lng": 72.9800},
        {"name": "Faizabad", "lat": 33.6601, "lng": 73.0735},
        {"name": "G-10 Markaz", "lat": 33.6750, "lng": 73.0150},
        {"name": "Saddar Rawalpindi", "lat": 33.5950, "lng": 73.0500},
    ]
    events = []
    for _ in range(count):
        incident = random.choice(incident_types)
        loc = random.choice(locations)
        event = {
            "event_id": str(uuid.uuid4()),
            "source": "1122_mock",
            "event_type": incident,
            "location": {"lat": loc["lat"], "lng": loc["lng"], "name": loc["name"]},
            "timestamp": datetime.utcnow().isoformat(),
            "severity": round(random.uniform(0.5, 1.0), 2),
            "confidence": 0.95,
            "raw_text": f"1122 Emergency call: {incident} at {loc['name']}",
            "structured_data": {"caller_type": "citizen", "dispatched": True, "mock": True},
            "source_reliability": 0.95,
        }
        events.append(event)
        stream_client.publish_event(event)
    return events

