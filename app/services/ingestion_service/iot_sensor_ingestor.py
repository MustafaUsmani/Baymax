"""
CIRO+ IoT & Environmental Sensor Ingestor
Real API integrations:
  - OpenAQ v2 API (free)  → Air quality (PM2.5, PM10, AQI)
Fallback: mock water level sensors, electricity grid stress, AQI
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

OPENAQ_KEY = os.environ.get("OPENAQ_API_KEY")
TIMEOUT = httpx.Timeout(15.0)

# Pakistan cities for air quality monitoring
AQ_CITIES = ["Islamabad", "Lahore", "Karachi", "Peshawar", "Rawalpindi", "Faisalabad"]


# ══════════════════════════════════════════════════════════════════════
# 1. OPENAQ  — Air Quality  (free)
# ══════════════════════════════════════════════════════════════════════
def fetch_openaq_air_quality() -> List[Dict[str, Any]]:
    """Fetch latest air quality readings from OpenAQ for Pakistan cities."""
    events = []

    for city in AQ_CITIES:
        try:
            url = "https://api.openaq.org/v2/latest"
            params = {"city": city, "country": "PK", "limit": 5}
            headers = {}
            if OPENAQ_KEY:
                headers["X-API-Key"] = OPENAQ_KEY

            resp = httpx.get(url, params=params, headers=headers, timeout=TIMEOUT)
            resp.raise_for_status()
            results = resp.json().get("results", [])

            for station in results:
                location_name = station.get("location", city)
                coords = station.get("coordinates", {})
                lat = coords.get("latitude", 0)
                lng = coords.get("longitude", 0)

                measurements = station.get("measurements", [])
                pm25 = 0
                pm10 = 0
                for m in measurements:
                    param = m.get("parameter", "")
                    value = m.get("value", 0)
                    if param == "pm25":
                        pm25 = value
                    elif param == "pm10":
                        pm10 = value

                # AQI severity
                severity = 0.0
                event_type = "air_quality_good"
                if pm25 >= 250:
                    event_type = "air_quality_hazardous"
                    severity = 1.0
                elif pm25 >= 150:
                    event_type = "air_quality_very_unhealthy"
                    severity = 0.8
                elif pm25 >= 55:
                    event_type = "air_quality_unhealthy"
                    severity = 0.5
                elif pm25 >= 35:
                    event_type = "air_quality_moderate"
                    severity = 0.3

                event = {
                    "event_id": str(uuid.uuid4()),
                    "source": "openaq",
                    "event_type": event_type,
                    "location": {"lat": lat, "lng": lng, "name": location_name},
                    "timestamp": datetime.utcnow().isoformat(),
                    "severity": round(severity, 2),
                    "confidence": 0.90,
                    "raw_text": f"Air quality {location_name}: PM2.5={pm25} µg/m³, PM10={pm10} µg/m³",
                    "structured_data": {
                        "pm25": pm25, "pm10": pm10,
                        "station": location_name,
                        "measurements": measurements,
                        "provider": "OpenAQ",
                    },
                    "source_reliability": 0.88,
                }
                events.append(event)
                stream_client.publish_event(event)

            logger.info(f"OpenAQ {city}: {len(results)} stations")

        except Exception as e:
            logger.warning(f"OpenAQ {city} failed: {e}")

    if not events:
        logger.warning("All OpenAQ calls failed — using mock fallback")
        return _mock_iot_data()

    return events


# ══════════════════════════════════════════════════════════════════════
# 2. MOCK WATER LEVEL SENSORS
# ══════════════════════════════════════════════════════════════════════
def fetch_water_level_sensors() -> List[Dict[str, Any]]:
    """
    Mock river/nullah water level sensors for flood monitoring.
    No free public API for Pakistan water levels — must be mocked.
    """
    import random

    sensors = [
        {"name": "Nullah Lai Sensor (Rawalpindi)", "lat": 33.5651, "lng": 73.0169, "normal_m": 1.5, "danger_m": 4.0},
        {"name": "Soan River Sensor", "lat": 33.6500, "lng": 72.9500, "normal_m": 2.0, "danger_m": 5.0},
        {"name": "Margalla Drainage Sensor", "lat": 33.7300, "lng": 73.0600, "normal_m": 0.5, "danger_m": 2.0},
        {"name": "Korang Nullah Sensor", "lat": 33.6700, "lng": 73.1000, "normal_m": 1.0, "danger_m": 3.0},
    ]

    events = []
    for sensor in sensors:
        # Simulate water level
        level = sensor["normal_m"] + random.uniform(-0.5, 3.0)
        level = max(0, level)
        danger_ratio = level / sensor["danger_m"]

        severity = 0.0
        event_type = "water_level_normal"
        if danger_ratio >= 1.0:
            event_type = "water_level_critical"
            severity = 1.0
        elif danger_ratio >= 0.8:
            event_type = "water_level_high"
            severity = 0.7
        elif danger_ratio >= 0.6:
            event_type = "water_level_elevated"
            severity = 0.4

        event = {
            "event_id": str(uuid.uuid4()),
            "source": "water_sensor_mock",
            "event_type": event_type,
            "location": {"lat": sensor["lat"], "lng": sensor["lng"], "name": sensor["name"]},
            "timestamp": datetime.utcnow().isoformat(),
            "severity": round(severity, 2),
            "confidence": 0.92,
            "raw_text": f"{sensor['name']}: water level {level:.1f}m (danger: {sensor['danger_m']}m)",
            "structured_data": {
                "water_level_m": round(level, 2),
                "danger_level_m": sensor["danger_m"],
                "danger_ratio": round(danger_ratio, 2),
                "mock": True,
            },
            "source_reliability": 0.90,
        }
        events.append(event)
        stream_client.publish_event(event)

    return events


# ══════════════════════════════════════════════════════════════════════
# 3. MOCK POWER GRID STRESS
# ══════════════════════════════════════════════════════════════════════
def fetch_power_grid_status() -> List[Dict[str, Any]]:
    """
    Mock electricity grid stress data.
    No free API for Pakistan power grid — simulates IESCO/LESCO load.
    """
    import random

    grids = [
        {"name": "IESCO (Islamabad)", "lat": 33.6844, "lng": 73.0479, "capacity_mw": 3000},
        {"name": "LESCO (Lahore)", "lat": 31.5204, "lng": 74.3587, "capacity_mw": 5000},
        {"name": "KE (Karachi)", "lat": 24.8607, "lng": 67.0011, "capacity_mw": 6000},
    ]

    events = []
    for grid in grids:
        load_pct = random.uniform(60, 105)  # Can exceed 100% = shortage

        severity = 0.0
        event_type = "power_grid_normal"
        if load_pct >= 100:
            event_type = "power_outage_risk"
            severity = min(1.0, (load_pct - 95) / 15)
        elif load_pct >= 90:
            event_type = "power_grid_stressed"
            severity = 0.5
        elif load_pct >= 80:
            event_type = "power_grid_high_load"
            severity = 0.3

        event = {
            "event_id": str(uuid.uuid4()),
            "source": "power_grid_mock",
            "event_type": event_type,
            "location": {"lat": grid["lat"], "lng": grid["lng"], "name": grid["name"]},
            "timestamp": datetime.utcnow().isoformat(),
            "severity": round(severity, 2),
            "confidence": 0.85,
            "raw_text": f"{grid['name']}: load {load_pct:.0f}% of {grid['capacity_mw']}MW capacity",
            "structured_data": {
                "load_pct": round(load_pct, 1),
                "capacity_mw": grid["capacity_mw"],
                "mock": True,
            },
            "source_reliability": 0.85,
        }
        events.append(event)
        stream_client.publish_event(event)

    return events


# ══════════════════════════════════════════════════════════════════════
# 4. FETCH ALL IoT / SENSOR DATA
# ══════════════════════════════════════════════════════════════════════
def fetch_all_iot_sensors() -> List[Dict[str, Any]]:
    """Run all IoT/sensor ingestors."""
    all_events = []
    all_events.extend(fetch_openaq_air_quality())
    all_events.extend(fetch_water_level_sensors())
    all_events.extend(fetch_power_grid_status())
    logger.info(f"IoT/Sensor ingestor: total {len(all_events)} events")
    return all_events


# ══════════════════════════════════════════════════════════════════════
# MOCK FALLBACK
# ══════════════════════════════════════════════════════════════════════
def _mock_iot_data() -> List[Dict[str, Any]]:
    events = []
    events.extend(fetch_water_level_sensors())
    events.extend(fetch_power_grid_status())
    return events
