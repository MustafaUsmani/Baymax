"""
CIRO+ Master Data Ingestor
Orchestrates all data source ingestors and provides a unified interface.
"""

import logging
import time
from typing import Dict, Any, List

from app.services.ingestion_service.social_ingestor import fetch_all_social_sources
from app.services.ingestion_service.weather_ingestor import fetch_all_weather
from app.services.ingestion_service.traffic_ingestor import fetch_all_traffic
from app.services.ingestion_service.economic_ingestor import fetch_all_economic
from app.services.ingestion_service.geopolitics_ingestor import fetch_all_geopolitical
from app.services.ingestion_service.iot_sensor_ingestor import fetch_all_iot_sensors
from app.services.ingestion_service.emergency_mock_generator import generate_emergency_batch

logger = logging.getLogger(__name__)


def run_full_ingestion_cycle() -> Dict[str, Any]:
    """
    Run a single complete ingestion cycle across ALL data sources.
    Returns a summary of what was ingested.
    """
    start = time.time()
    summary = {}

    # 1. Social & News
    logger.info("═══ Ingesting: Social & News ═══")
    try:
        social_events = fetch_all_social_sources()
        summary["social_news"] = {"count": len(social_events), "status": "ok"}
    except Exception as e:
        logger.error(f"Social ingestion failed: {e}")
        summary["social_news"] = {"count": 0, "status": f"error: {e}"}

    # 2. Weather
    logger.info("═══ Ingesting: Weather ═══")
    try:
        weather_events = fetch_all_weather()
        summary["weather"] = {"count": len(weather_events), "status": "ok"}
    except Exception as e:
        logger.error(f"Weather ingestion failed: {e}")
        summary["weather"] = {"count": 0, "status": f"error: {e}"}

    # 3. Traffic
    logger.info("═══ Ingesting: Traffic ═══")
    try:
        traffic_events = fetch_all_traffic()
        summary["traffic"] = {"count": len(traffic_events), "status": "ok"}
    except Exception as e:
        logger.error(f"Traffic ingestion failed: {e}")
        summary["traffic"] = {"count": 0, "status": f"error: {e}"}

    # 4. Economic
    logger.info("═══ Ingesting: Economic ═══")
    try:
        economic_events = fetch_all_economic()
        summary["economic"] = {"count": len(economic_events), "status": "ok"}
    except Exception as e:
        logger.error(f"Economic ingestion failed: {e}")
        summary["economic"] = {"count": 0, "status": f"error: {e}"}

    # 5. Geopolitical
    logger.info("═══ Ingesting: Geopolitical ═══")
    try:
        geo_events = fetch_all_geopolitical()
        summary["geopolitical"] = {"count": len(geo_events), "status": "ok"}
    except Exception as e:
        logger.error(f"Geopolitical ingestion failed: {e}")
        summary["geopolitical"] = {"count": 0, "status": f"error: {e}"}

    # 6. IoT / Sensors
    logger.info("═══ Ingesting: IoT & Sensors ═══")
    try:
        iot_events = fetch_all_iot_sensors()
        summary["iot_sensors"] = {"count": len(iot_events), "status": "ok"}
    except Exception as e:
        logger.error(f"IoT ingestion failed: {e}")
        summary["iot_sensors"] = {"count": 0, "status": f"error: {e}"}

    # 7. Emergency mock
    logger.info("═══ Ingesting: Emergency Mock ═══")
    try:
        emergency_events = generate_emergency_batch(count=5)
        summary["emergency_mock"] = {"count": len(emergency_events), "status": "ok"}
    except Exception as e:
        logger.error(f"Emergency mock failed: {e}")
        summary["emergency_mock"] = {"count": 0, "status": f"error: {e}"}

    elapsed = round(time.time() - start, 2)
    total = sum(s["count"] for s in summary.values())

    logger.info(f"═══ Full ingestion cycle: {total} events in {elapsed}s ═══")

    return {
        "total_events": total,
        "elapsed_seconds": elapsed,
        "sources": summary,
    }
