"""
CIRO+ Weather & Environmental Data Ingestor
Real API integrations:
  - OpenWeatherMap (free tier — 1000 calls/day)
  - WeatherAPI.com  (free tier — 1M calls/month)
Fallback: realistic mock weather data for Pakistan cities
"""

import os
import uuid
import logging
from datetime import datetime
from typing import List, Dict, Any, Optional

import httpx
from dotenv import load_dotenv

from app.services.redis_streams import stream_client

load_dotenv()
logger = logging.getLogger(__name__)

OWM_KEY = os.environ.get("OPENWEATHERMAP_API_KEY")
WAPI_KEY = os.environ.get("WEATHERAPI_KEY")
TIMEOUT = httpx.Timeout(15.0)

# Pakistan cities to monitor
DEFAULT_CITIES = [
    {"name": "Islamabad", "lat": 33.6844, "lon": 73.0479},
    {"name": "Rawalpindi", "lat": 33.5651, "lon": 73.0169},
    {"name": "Lahore", "lat": 31.5204, "lon": 74.3587},
    {"name": "Karachi", "lat": 24.8607, "lon": 67.0011},
    {"name": "Peshawar", "lat": 34.0151, "lon": 71.5249},
    {"name": "Quetta", "lat": 30.1798, "lon": 66.9750},
    {"name": "Multan", "lat": 30.1575, "lon": 71.5249},
    {"name": "Faisalabad", "lat": 31.4504, "lon": 73.1350},
]


# ══════════════════════════════════════════════════════════════════════
# 1. OPENWEATHERMAP  (free tier)
# ══════════════════════════════════════════════════════════════════════
def fetch_openweathermap(
    cities: List[Dict] = None,
) -> List[Dict[str, Any]]:
    """Fetch current weather + alerts from OpenWeatherMap."""
    if not OWM_KEY:
        logger.warning("OPENWEATHERMAP_API_KEY not set — using mock fallback")
        return _mock_weather_data()

    cities = cities or DEFAULT_CITIES
    events = []

    for city in cities:
        try:
            # Current weather
            url = "https://api.openweathermap.org/data/2.5/weather"
            params = {
                "lat": city["lat"],
                "lon": city["lon"],
                "appid": OWM_KEY,
                "units": "metric",
            }
            resp = httpx.get(url, params=params, timeout=TIMEOUT)
            resp.raise_for_status()
            data = resp.json()

            temp = data.get("main", {}).get("temp", 0)
            feels_like = data.get("main", {}).get("feels_like", 0)
            humidity = data.get("main", {}).get("humidity", 0)
            rain_1h = data.get("rain", {}).get("1h", 0)
            rain_3h = data.get("rain", {}).get("3h", 0)
            wind = data.get("wind", {}).get("speed", 0)
            description = data.get("weather", [{}])[0].get("description", "")

            # Detect crisis-level conditions
            severity = 0.0
            event_type = "weather_update"

            if temp >= 45:
                event_type = "heatwave"
                severity = min(1.0, (temp - 40) / 15)
            elif temp >= 40:
                event_type = "heat_advisory"
                severity = 0.5
            if rain_1h >= 30 or rain_3h >= 60:
                event_type = "flood_risk"
                severity = max(severity, min(1.0, rain_1h / 50))
            elif rain_1h >= 10:
                event_type = "heavy_rain"
                severity = max(severity, 0.4)
            if wind >= 60:
                event_type = "storm_warning"
                severity = max(severity, 0.7)

            raw_text = (
                f"Weather {city['name']}: {description}, "
                f"Temp {temp}°C (feels {feels_like}°C), "
                f"Humidity {humidity}%, Rain 1h: {rain_1h}mm, Wind: {wind} km/h"
            )

            event = {
                "event_id": str(uuid.uuid4()),
                "source": "openweathermap",
                "event_type": event_type,
                "location": {"lat": city["lat"], "lng": city["lon"], "name": city["name"]},
                "timestamp": datetime.utcnow().isoformat(),
                "severity": round(severity, 2),
                "confidence": 0.92,
                "raw_text": raw_text,
                "structured_data": {
                    "temperature_c": temp,
                    "feels_like_c": feels_like,
                    "humidity_pct": humidity,
                    "rain_1h_mm": rain_1h,
                    "rain_3h_mm": rain_3h,
                    "wind_speed_kmh": wind,
                    "description": description,
                    "provider": "OpenWeatherMap",
                },
                "source_reliability": 0.92,
            }
            events.append(event)
            stream_client.publish_event(event)

            logger.info(f"OWM {city['name']}: {temp}°C, rain={rain_1h}mm, event={event_type}")

        except Exception as e:
            logger.warning(f"OWM {city['name']} failed: {e}")

    if not events:
        logger.warning("All OWM calls failed — using mock fallback")
        return _mock_weather_data()

    return events


# ══════════════════════════════════════════════════════════════════════
# 2. WEATHERAPI.COM  (free tier)
# ══════════════════════════════════════════════════════════════════════
def fetch_weatherapi(
    cities: List[Dict] = None,
) -> List[Dict[str, Any]]:
    """Fetch current + alerts from WeatherAPI.com."""
    if not WAPI_KEY:
        logger.warning("WEATHERAPI_KEY not set — using mock fallback")
        return _mock_weather_data()

    cities = cities or DEFAULT_CITIES
    events = []

    for city in cities:
        try:
            url = "https://api.weatherapi.com/v1/current.json"
            params = {"key": WAPI_KEY, "q": f"{city['lat']},{city['lon']}", "aqi": "yes"}

            resp = httpx.get(url, params=params, timeout=TIMEOUT)
            resp.raise_for_status()
            data = resp.json()

            current = data.get("current", {})
            temp = current.get("temp_c", 0)
            precip = current.get("precip_mm", 0)
            humidity = current.get("humidity", 0)
            wind = current.get("wind_kph", 0)
            uv = current.get("uv", 0)
            condition = current.get("condition", {}).get("text", "")

            # Air quality
            aqi = current.get("air_quality", {})
            pm25 = aqi.get("pm2_5", 0)
            us_epa_index = aqi.get("us-epa-index", 0)

            severity = 0.0
            event_type = "weather_update"
            if temp >= 45:
                event_type = "heatwave"
                severity = min(1.0, (temp - 40) / 15)
            if precip >= 30:
                event_type = "flood_risk"
                severity = max(severity, min(1.0, precip / 50))
            if pm25 >= 150:
                event_type = "air_quality_hazard"
                severity = max(severity, 0.7)

            raw_text = (
                f"WeatherAPI {city['name']}: {condition}, {temp}°C, "
                f"Precip {precip}mm, Wind {wind}kph, UV {uv}, PM2.5 {pm25}"
            )

            event = {
                "event_id": str(uuid.uuid4()),
                "source": "weatherapi",
                "event_type": event_type,
                "location": {"lat": city["lat"], "lng": city["lon"], "name": city["name"]},
                "timestamp": datetime.utcnow().isoformat(),
                "severity": round(severity, 2),
                "confidence": 0.90,
                "raw_text": raw_text,
                "structured_data": {
                    "temperature_c": temp, "precip_mm": precip,
                    "humidity_pct": humidity, "wind_kph": wind,
                    "uv_index": uv, "condition": condition,
                    "pm25": pm25, "us_epa_index": us_epa_index,
                    "provider": "WeatherAPI",
                },
                "source_reliability": 0.90,
            }
            events.append(event)
            stream_client.publish_event(event)

        except Exception as e:
            logger.warning(f"WeatherAPI {city['name']} failed: {e}")

    if not events:
        return _mock_weather_data()

    return events


# ══════════════════════════════════════════════════════════════════════
# 3. FETCH ALL WEATHER SOURCES
# ══════════════════════════════════════════════════════════════════════
def fetch_all_weather() -> List[Dict[str, Any]]:
    """Run all weather ingestors."""
    all_events = []
    all_events.extend(fetch_openweathermap())
    all_events.extend(fetch_weatherapi())
    logger.info(f"Weather ingestor: total {len(all_events)} events")
    return all_events


# ══════════════════════════════════════════════════════════════════════
# MOCK FALLBACK
# ══════════════════════════════════════════════════════════════════════
def _mock_weather_data() -> List[Dict[str, Any]]:
    """Realistic mock weather data for Pakistan cities."""
    mocks = [
        {"city": "Islamabad", "lat": 33.6844, "lng": 73.0479, "temp": 42, "rain": 0, "event": "heat_advisory", "sev": 0.5},
        {"city": "Lahore", "lat": 31.5204, "lng": 74.3587, "temp": 46, "rain": 0, "event": "heatwave", "sev": 0.8},
        {"city": "Karachi", "lat": 24.8607, "lng": 67.0011, "temp": 38, "rain": 45, "event": "flood_risk", "sev": 0.7},
        {"city": "Peshawar", "lat": 34.0151, "lng": 71.5249, "temp": 40, "rain": 25, "event": "heavy_rain", "sev": 0.5},
        {"city": "Rawalpindi", "lat": 33.5651, "lng": 73.0169, "temp": 41, "rain": 35, "event": "flood_risk", "sev": 0.6},
    ]
    events = []
    for m in mocks:
        event = {
            "event_id": str(uuid.uuid4()),
            "source": "weather_mock",
            "event_type": m["event"],
            "location": {"lat": m["lat"], "lng": m["lng"], "name": m["city"]},
            "timestamp": datetime.utcnow().isoformat(),
            "severity": m["sev"],
            "confidence": 0.85,
            "raw_text": f"Mock weather {m['city']}: {m['temp']}°C, rain {m['rain']}mm",
            "structured_data": {"temperature_c": m["temp"], "rain_mm": m["rain"], "mock": True},
            "source_reliability": 0.85,
        }
        events.append(event)
        stream_client.publish_event(event)
    return events
