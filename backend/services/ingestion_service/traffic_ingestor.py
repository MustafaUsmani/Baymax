"""
CIRO+ Traffic & Mobility Ingestor
Real API integrations:
  - TomTom Traffic Flow API (free tier — 2500 calls/day)
  - OpenRouteService Directions API (free tier)
Fallback: realistic mock traffic data for Pakistan corridors
"""

import os
import uuid
import logging
from datetime import datetime
from typing import List, Dict, Any

import httpx
from dotenv import load_dotenv

from app.services.redis_streams import stream_client

load_dotenv()
logger = logging.getLogger(__name__)

TOMTOM_KEY = os.environ.get("TOMTOM_API_KEY")
ORS_KEY = os.environ.get("OPENROUTESERVICE_API_KEY")
TIMEOUT = httpx.Timeout(15.0)

# Key road segments to monitor (start_lat,start_lon → end_lat,end_lon)
MONITORED_CORRIDORS = [
    {"name": "Kashmir Highway (Islamabad)", "lat": 33.7070, "lon": 73.0551},
    {"name": "GT Road (Rawalpindi)", "lat": 33.5651, "lon": 73.0169},
    {"name": "Islamabad Expressway", "lat": 33.6600, "lon": 73.0800},
    {"name": "Faizabad Interchange", "lat": 33.6601, "lon": 73.0735},
    {"name": "Murree Road", "lat": 33.6200, "lon": 73.0700},
    {"name": "IJP Road", "lat": 33.6100, "lon": 73.0200},
    {"name": "Faisal Avenue", "lat": 33.7000, "lon": 73.0500},
    {"name": "Blue Area Jinnah Avenue", "lat": 33.7100, "lon": 73.0580},
]


# ══════════════════════════════════════════════════════════════════════
# 1. TOMTOM TRAFFIC FLOW  (free tier — 2500/day)
# ══════════════════════════════════════════════════════════════════════
def fetch_tomtom_traffic(
    corridors: List[Dict] = None,
) -> List[Dict[str, Any]]:
    """Fetch real-time traffic flow from TomTom for key corridors."""
    if not TOMTOM_KEY:
        logger.warning("TOMTOM_API_KEY not set — using mock fallback")
        return _mock_traffic_data()

    corridors = corridors or MONITORED_CORRIDORS
    events = []

    for corr in corridors:
        try:
            # Traffic Flow Segment Data
            url = (
                f"https://api.tomtom.com/traffic/services/4/flowSegmentData/"
                f"absolute/10/json"
            )
            params = {
                "key": TOMTOM_KEY,
                "point": f"{corr['lat']},{corr['lon']}",
            }
            resp = httpx.get(url, params=params, timeout=TIMEOUT)
            resp.raise_for_status()
            data = resp.json().get("flowSegmentData", {})

            current_speed = data.get("currentSpeed", 0)
            free_flow_speed = data.get("freeFlowSpeed", 60)
            current_travel_time = data.get("currentTravelTime", 0)
            free_flow_travel_time = data.get("freeFlowTravelTime", 0)
            confidence_val = data.get("confidence", 0.5)

            # Calculate congestion ratio
            congestion_ratio = 1.0 - (current_speed / free_flow_speed) if free_flow_speed > 0 else 0
            congestion_ratio = max(0, min(1, congestion_ratio))

            severity = 0.0
            event_type = "traffic_normal"
            congestion_level = "normal"

            if congestion_ratio >= 0.7:
                event_type = "traffic_blockage"
                severity = min(1.0, congestion_ratio)
                congestion_level = "severe"
            elif congestion_ratio >= 0.5:
                event_type = "traffic_congestion"
                severity = congestion_ratio * 0.8
                congestion_level = "heavy"
            elif congestion_ratio >= 0.3:
                event_type = "traffic_slow"
                severity = congestion_ratio * 0.5
                congestion_level = "moderate"

            raw_text = (
                f"Traffic {corr['name']}: {congestion_level} congestion. "
                f"Current speed {current_speed} km/h (free flow: {free_flow_speed} km/h). "
                f"Travel time {current_travel_time}s vs normal {free_flow_travel_time}s."
            )

            event = {
                "event_id": str(uuid.uuid4()),
                "source": "tomtom",
                "event_type": event_type,
                "location": {"lat": corr["lat"], "lng": corr["lon"], "name": corr["name"]},
                "timestamp": datetime.utcnow().isoformat(),
                "severity": round(severity, 2),
                "confidence": confidence_val,
                "raw_text": raw_text,
                "structured_data": {
                    "current_speed_kmh": current_speed,
                    "free_flow_speed_kmh": free_flow_speed,
                    "congestion_ratio": round(congestion_ratio, 2),
                    "congestion_level": congestion_level,
                    "current_travel_time_s": current_travel_time,
                    "free_flow_travel_time_s": free_flow_travel_time,
                    "provider": "TomTom",
                },
                "source_reliability": 0.88,
            }
            events.append(event)
            stream_client.publish_event(event)

            logger.info(f"TomTom {corr['name']}: {congestion_level} ({current_speed} km/h)")

        except Exception as e:
            logger.warning(f"TomTom {corr['name']} failed: {e}")

    if not events:
        logger.warning("All TomTom calls failed — using mock fallback")
        return _mock_traffic_data()

    return events


# ══════════════════════════════════════════════════════════════════════
# 2. OPENROUTESERVICE  (free tier — 2000 calls/day)
# ══════════════════════════════════════════════════════════════════════
def fetch_ors_route_check(
    start: Dict[str, float] = None,
    end: Dict[str, float] = None,
) -> Dict[str, Any]:
    """Check a route for travel time anomalies using OpenRouteService."""
    if not ORS_KEY:
        logger.warning("OPENROUTESERVICE_API_KEY not set — using mock")
        return _mock_route_check()

    start = start or {"lat": 33.6844, "lon": 73.0479}  # Islamabad
    end = end or {"lat": 33.5651, "lon": 73.0169}        # Rawalpindi

    try:
        url = "https://api.openrouteservice.org/v2/directions/driving-car"
        headers = {"Authorization": ORS_KEY}
        body = {
            "coordinates": [[start["lon"], start["lat"]], [end["lon"], end["lat"]]],
        }
        resp = httpx.post(url, json=body, headers=headers, timeout=TIMEOUT)
        resp.raise_for_status()
        route = resp.json().get("routes", [{}])[0]

        duration_s = route.get("summary", {}).get("duration", 0)
        distance_m = route.get("summary", {}).get("distance", 0)

        return {
            "event_id": str(uuid.uuid4()),
            "source": "openrouteservice",
            "event_type": "route_check",
            "location": {"lat": start["lat"], "lng": start["lon"], "name": "Route check"},
            "timestamp": datetime.utcnow().isoformat(),
            "severity": 0.0,
            "confidence": 0.85,
            "raw_text": f"Route {distance_m/1000:.1f} km, ETA {duration_s/60:.0f} min",
            "structured_data": {
                "duration_s": duration_s, "distance_m": distance_m,
                "provider": "OpenRouteService",
            },
            "source_reliability": 0.85,
        }

    except Exception as e:
        logger.warning(f"ORS route check failed: {e}")
        return _mock_route_check()


# ══════════════════════════════════════════════════════════════════════
# 3. FETCH ALL TRAFFIC
# ══════════════════════════════════════════════════════════════════════
def fetch_all_traffic() -> List[Dict[str, Any]]:
    """Run all traffic ingestors."""
    return fetch_tomtom_traffic()


# ══════════════════════════════════════════════════════════════════════
# MOCK FALLBACKS
# ══════════════════════════════════════════════════════════════════════
def _mock_traffic_data() -> List[Dict[str, Any]]:
    import random
    events = []
    for corr in MONITORED_CORRIDORS:
        congestion = random.choice(["normal", "moderate", "heavy", "severe"])
        speed = {"normal": 55, "moderate": 35, "heavy": 15, "severe": 5}[congestion]
        severity = {"normal": 0.1, "moderate": 0.3, "heavy": 0.6, "severe": 0.9}[congestion]
        event_type = "traffic_blockage" if congestion == "severe" else f"traffic_{congestion}"

        event = {
            "event_id": str(uuid.uuid4()),
            "source": "traffic_mock",
            "event_type": event_type,
            "location": {"lat": corr["lat"], "lng": corr["lon"], "name": corr["name"]},
            "timestamp": datetime.utcnow().isoformat(),
            "severity": severity,
            "confidence": 0.80,
            "raw_text": f"Mock traffic {corr['name']}: {congestion} ({speed} km/h)",
            "structured_data": {"speed_kmh": speed, "congestion": congestion, "mock": True},
            "source_reliability": 0.80,
        }
        events.append(event)
        stream_client.publish_event(event)
    return events


def _mock_route_check() -> Dict[str, Any]:
    return {
        "event_id": str(uuid.uuid4()),
        "source": "route_mock",
        "event_type": "route_check",
        "location": {"lat": 33.6844, "lng": 73.0479, "name": "Islamabad → Rawalpindi"},
        "timestamp": datetime.utcnow().isoformat(),
        "severity": 0.0,
        "confidence": 0.80,
        "raw_text": "Mock route: 18.5 km, ETA 35 min",
        "structured_data": {"duration_s": 2100, "distance_m": 18500, "mock": True},
        "source_reliability": 0.80,
    }
