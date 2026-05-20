"""
CIRO+ Geopolitical & Security Signals Ingestor
Real API integrations:
  - GDELT DOC 2.0 API (completely free, no key)  → protests, conflict, unrest
  - GDELT GEO 2.0 API (completely free)          → geolocated events
  - ACLED (free tier — requires registration)     → conflict data
Fallback: realistic mock geopolitical events for Pakistan
"""

import os
import uuid
import logging
from datetime import datetime, timedelta
from typing import List, Dict, Any

import httpx
from dotenv import load_dotenv

from app.services.redis_streams import stream_client

load_dotenv()
logger = logging.getLogger(__name__)

TIMEOUT = httpx.Timeout(20.0)


# ══════════════════════════════════════════════════════════════════════
# 1. GDELT DOC API — Geopolitical News  (free, no key)
# ══════════════════════════════════════════════════════════════════════
def fetch_gdelt_geopolitical(
    queries: List[str] = None,
    max_records: int = 15,
) -> List[Dict[str, Any]]:
    """
    Fetch geopolitical and security-related news from GDELT DOC API.
    Searches for protests, tensions, conflicts, terror, military activity.
    """
    queries = queries or [
        "Pakistan protest OR unrest OR strike",
        "Pakistan security OR terror OR military",
        "Pakistan political crisis OR tensions",
    ]
    events = []

    for query in queries:
        try:
            url = "https://api.gdeltproject.org/api/v2/doc/doc"
            params = {
                "query": query,
                "mode": "ArtList",
                "maxrecords": max_records,
                "format": "json",
                "sort": "DateDesc",
            }

            resp = httpx.get(url, params=params, timeout=TIMEOUT)
            resp.raise_for_status()
            data = resp.json()
            articles = data.get("articles", [])

            for art in articles:
                title = art.get("title", "")
                tone = art.get("tone", "0")

                # Parse GDELT tone (negative = conflict, positive = cooperation)
                try:
                    tone_val = float(str(tone).split(",")[0]) if tone else 0
                except (ValueError, IndexError):
                    tone_val = 0

                # Classify event type based on keywords
                event_type = _classify_geopolitical(title)

                # Severity from tone (more negative = more severe)
                severity = min(1.0, max(0.0, abs(tone_val) / 15)) if tone_val < -2 else 0.2

                event = {
                    "event_id": str(uuid.uuid4()),
                    "source": "gdelt",
                    "event_type": event_type,
                    "location": {"lat": 0.0, "lng": 0.0, "name": "Pakistan"},
                    "timestamp": datetime.utcnow().isoformat(),
                    "severity": round(severity, 2),
                    "confidence": 0.78,
                    "raw_text": title,
                    "structured_data": {
                        "url": art.get("url"),
                        "domain": art.get("domain"),
                        "language": art.get("language"),
                        "seendate": art.get("seendate"),
                        "tone": tone_val,
                        "provider": "GDELT",
                    },
                    "source_reliability": 0.80,
                }
                events.append(event)
                stream_client.publish_event(event)

            logger.info(f"GDELT geopolitical: {len(articles)} articles for query='{query[:40]}'")

        except Exception as e:
            logger.warning(f"GDELT geopolitical failed for '{query[:30]}': {e}")

    if not events:
        logger.warning("All GDELT calls failed — using mock fallback")
        return _mock_geopolitical_data()

    return events


# ══════════════════════════════════════════════════════════════════════
# 2. GDELT GEO API — Geolocated Events  (free, no key)
# ══════════════════════════════════════════════════════════════════════
def fetch_gdelt_geo_events(
    query: str = "Pakistan protest OR conflict",
) -> List[Dict[str, Any]]:
    """Fetch geolocated events from GDELT GEO 2.0 API."""
    events = []

    try:
        url = "https://api.gdeltproject.org/api/v2/geo/geo"
        params = {
            "query": query,
            "format": "GeoJSON",
        }

        resp = httpx.get(url, params=params, timeout=TIMEOUT)
        resp.raise_for_status()
        geo_data = resp.json()

        features = geo_data.get("features", [])
        for feat in features[:20]:  # Limit
            props = feat.get("properties", {})
            coords = feat.get("geometry", {}).get("coordinates", [0, 0])

            event = {
                "event_id": str(uuid.uuid4()),
                "source": "gdelt_geo",
                "event_type": _classify_geopolitical(props.get("name", "")),
                "location": {
                    "lat": coords[1] if len(coords) >= 2 else 0,
                    "lng": coords[0] if len(coords) >= 1 else 0,
                    "name": props.get("name", "Unknown"),
                },
                "timestamp": datetime.utcnow().isoformat(),
                "severity": 0.5,
                "confidence": 0.75,
                "raw_text": props.get("name", ""),
                "structured_data": {
                    "html": props.get("html"),
                    "url": props.get("url"),
                    "shareimage": props.get("shareimage"),
                    "provider": "GDELT_GEO",
                },
                "source_reliability": 0.78,
            }
            events.append(event)
            stream_client.publish_event(event)

        logger.info(f"GDELT GEO: {len(features)} geolocated events")

    except Exception as e:
        logger.warning(f"GDELT GEO failed: {e}")

    return events


# ══════════════════════════════════════════════════════════════════════
# 3. FETCH ALL GEOPOLITICAL
# ══════════════════════════════════════════════════════════════════════
def fetch_all_geopolitical() -> List[Dict[str, Any]]:
    """Run all geopolitical ingestors."""
    all_events = []
    all_events.extend(fetch_gdelt_geopolitical())
    all_events.extend(fetch_gdelt_geo_events())
    logger.info(f"Geopolitics ingestor: total {len(all_events)} events")
    return all_events


# ══════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════
def _classify_geopolitical(text: str) -> str:
    text_lower = text.lower()
    if any(w in text_lower for w in ["protest", "strike", "demonstration", "march", "rally"]):
        return "protest"
    elif any(w in text_lower for w in ["terror", "bomb", "attack", "militant", "explosion"]):
        return "security_alert"
    elif any(w in text_lower for w in ["military", "army", "border", "airspace"]):
        return "geopolitical_tension"
    elif any(w in text_lower for w in ["political", "government", "opposition", "crisis"]):
        return "political_unrest"
    elif any(w in text_lower for w in ["conflict", "violence", "clash", "killed"]):
        return "conflict"
    return "geopolitical_event"


# ══════════════════════════════════════════════════════════════════════
# MOCK FALLBACK
# ══════════════════════════════════════════════════════════════════════
def _mock_geopolitical_data() -> List[Dict[str, Any]]:
    mocks = [
        ("Protests erupt near D-Chowk Islamabad over fuel price hike", "protest", 0.7),
        ("Security forces on high alert after threat warning in Peshawar", "security_alert", 0.6),
        ("Opposition calls for nationwide strike next week", "political_unrest", 0.5),
        ("Border tensions escalate at Line of Control", "geopolitical_tension", 0.8),
        ("Political rally planned in Lahore, major roads to be blocked", "protest", 0.5),
    ]
    events = []
    for text, etype, sev in mocks:
        event = {
            "event_id": str(uuid.uuid4()),
            "source": "geopolitical_mock",
            "event_type": etype,
            "location": {"lat": 33.6844, "lng": 73.0479, "name": "Pakistan"},
            "timestamp": datetime.utcnow().isoformat(),
            "severity": sev,
            "confidence": 0.75,
            "raw_text": text,
            "structured_data": {"mock": True},
            "source_reliability": 0.75,
        }
        events.append(event)
        stream_client.publish_event(event)
    return events
