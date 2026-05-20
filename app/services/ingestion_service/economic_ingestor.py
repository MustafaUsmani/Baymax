"""
CIRO+ Economic Signals Ingestor
Real API integrations:
  - Open Exchange Rates (free, no key)  → currency crash detection
  - World Bank API (free, no key)       → inflation / CPI data
Fallback: realistic mock economic data for Pakistan
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

TIMEOUT = httpx.Timeout(15.0)

# Baseline values for anomaly detection (approximate recent values for Pakistan)
PKR_BASELINE = 280.0       # PKR per USD baseline
FUEL_BASELINE = 290.0      # PKR per litre (petrol)
CPI_BASELINE = 28.0        # CPI inflation % baseline


# ══════════════════════════════════════════════════════════════════════
# 1. EXCHANGE RATES  (Open Exchange Rates — free, no key)
# ══════════════════════════════════════════════════════════════════════
def fetch_exchange_rates() -> List[Dict[str, Any]]:
    """Fetch latest USD→PKR rate and detect currency shocks."""
    url = "https://open.er-api.com/v6/latest/USD"
    events = []

    try:
        resp = httpx.get(url, timeout=TIMEOUT)
        resp.raise_for_status()
        data = resp.json()

        rates = data.get("rates", {})
        pkr_rate = rates.get("PKR", 0)
        inr_rate = rates.get("INR", 0)
        gbp_rate = rates.get("GBP", 0)
        eur_rate = rates.get("EUR", 0)

        # Detect PKR crash
        if pkr_rate > 0 and PKR_BASELINE > 0:
            change_pct = ((pkr_rate - PKR_BASELINE) / PKR_BASELINE) * 100
        else:
            change_pct = 0

        severity = 0.0
        event_type = "exchange_rate_update"

        if abs(change_pct) >= 10:
            event_type = "currency_crash" if change_pct > 0 else "currency_surge"
            severity = min(1.0, abs(change_pct) / 20)
        elif abs(change_pct) >= 5:
            event_type = "currency_volatility"
            severity = 0.4

        raw_text = (
            f"USD/PKR: {pkr_rate:.2f} (change: {change_pct:+.1f}% from baseline {PKR_BASELINE}). "
            f"USD/INR: {inr_rate:.2f}, USD/GBP: {gbp_rate:.4f}, USD/EUR: {eur_rate:.4f}"
        )

        event = {
            "event_id": str(uuid.uuid4()),
            "source": "exchange_rate_api",
            "event_type": event_type,
            "location": {"lat": 0.0, "lng": 0.0, "name": "National / Global"},
            "timestamp": datetime.utcnow().isoformat(),
            "severity": round(severity, 2),
            "confidence": 0.95,
            "raw_text": raw_text,
            "structured_data": {
                "usd_pkr": pkr_rate,
                "usd_inr": inr_rate,
                "usd_gbp": gbp_rate,
                "usd_eur": eur_rate,
                "change_pct_from_baseline": round(change_pct, 2),
                "baseline_pkr": PKR_BASELINE,
                "provider": "open.er-api.com",
            },
            "source_reliability": 0.95,
        }
        events.append(event)
        stream_client.publish_event(event)

        logger.info(f"Exchange rates: USD/PKR {pkr_rate:.2f} ({change_pct:+.1f}%)")

    except Exception as e:
        logger.warning(f"Exchange rate API failed: {e} — using mock")
        events.extend(_mock_exchange_data())

    return events


# ══════════════════════════════════════════════════════════════════════
# 2. WORLD BANK  — Inflation/CPI  (free, no key)
# ══════════════════════════════════════════════════════════════════════
def fetch_worldbank_inflation() -> List[Dict[str, Any]]:
    """Fetch Pakistan CPI inflation data from World Bank API."""
    url = "https://api.worldbank.org/v2/country/PAK/indicator/FP.CPI.TOTL.ZG"
    params = {"format": "json", "per_page": 5, "mrv": 5}
    events = []

    try:
        resp = httpx.get(url, params=params, timeout=TIMEOUT)
        resp.raise_for_status()
        data = resp.json()

        # World Bank returns [metadata, data_array]
        if len(data) >= 2 and data[1]:
            records = data[1]
            latest = records[0]
            cpi_value = latest.get("value")
            year = latest.get("date")

            if cpi_value is not None:
                severity = 0.0
                event_type = "inflation_update"

                if cpi_value >= 30:
                    event_type = "inflation_shock"
                    severity = min(1.0, cpi_value / 40)
                elif cpi_value >= 20:
                    event_type = "inflation_high"
                    severity = 0.5
                elif cpi_value >= 10:
                    event_type = "inflation_moderate"
                    severity = 0.3

                # Build trend
                trend = []
                for r in records:
                    if r.get("value") is not None:
                        trend.append({"year": r["date"], "cpi": round(r["value"], 1)})

                raw_text = f"Pakistan CPI inflation ({year}): {cpi_value:.1f}%"

                event = {
                    "event_id": str(uuid.uuid4()),
                    "source": "worldbank",
                    "event_type": event_type,
                    "location": {"lat": 30.3753, "lng": 69.3451, "name": "Pakistan (National)"},
                    "timestamp": datetime.utcnow().isoformat(),
                    "severity": round(severity, 2),
                    "confidence": 0.95,
                    "raw_text": raw_text,
                    "structured_data": {
                        "cpi_inflation_pct": round(cpi_value, 1),
                        "year": year,
                        "trend": trend,
                        "provider": "World Bank",
                    },
                    "source_reliability": 0.95,
                }
                events.append(event)
                stream_client.publish_event(event)

                logger.info(f"World Bank CPI: {cpi_value:.1f}% ({year})")

    except Exception as e:
        logger.warning(f"World Bank API failed: {e} — using mock")
        events.extend(_mock_inflation_data())

    return events


# ══════════════════════════════════════════════════════════════════════
# 3. FUEL PRICES  (Pakistan-specific — MOCK, no free API)
# ══════════════════════════════════════════════════════════════════════
def fetch_fuel_prices() -> List[Dict[str, Any]]:
    """
    Pakistan fuel prices change monthly via government gazette.
    No reliable free API exists — this generates realistic mock data
    and should be replaced with a scraper for OGRA.gov.pk or a manual feed.
    """
    return _mock_fuel_data()


# ══════════════════════════════════════════════════════════════════════
# 4. FETCH ALL ECONOMIC SIGNALS
# ══════════════════════════════════════════════════════════════════════
def fetch_all_economic() -> List[Dict[str, Any]]:
    """Run all economic ingestors."""
    all_events = []
    all_events.extend(fetch_exchange_rates())
    all_events.extend(fetch_worldbank_inflation())
    all_events.extend(fetch_fuel_prices())
    logger.info(f"Economic ingestor: total {len(all_events)} events")
    return all_events


# ══════════════════════════════════════════════════════════════════════
# MOCK FALLBACKS
# ══════════════════════════════════════════════════════════════════════
def _mock_exchange_data() -> List[Dict[str, Any]]:
    event = {
        "event_id": str(uuid.uuid4()),
        "source": "exchange_mock",
        "event_type": "currency_volatility",
        "location": {"lat": 0.0, "lng": 0.0, "name": "National"},
        "timestamp": datetime.utcnow().isoformat(),
        "severity": 0.4,
        "confidence": 0.85,
        "raw_text": "Mock: USD/PKR 295.50 (+5.5% from baseline 280.0)",
        "structured_data": {"usd_pkr": 295.50, "change_pct": 5.5, "mock": True},
        "source_reliability": 0.85,
    }
    stream_client.publish_event(event)
    return [event]


def _mock_inflation_data() -> List[Dict[str, Any]]:
    event = {
        "event_id": str(uuid.uuid4()),
        "source": "inflation_mock",
        "event_type": "inflation_high",
        "location": {"lat": 30.3753, "lng": 69.3451, "name": "Pakistan"},
        "timestamp": datetime.utcnow().isoformat(),
        "severity": 0.5,
        "confidence": 0.85,
        "raw_text": "Mock: Pakistan CPI inflation 24.5%",
        "structured_data": {"cpi_pct": 24.5, "mock": True},
        "source_reliability": 0.85,
    }
    stream_client.publish_event(event)
    return [event]


def _mock_fuel_data() -> List[Dict[str, Any]]:
    import random
    current_petrol = FUEL_BASELINE + random.uniform(-10, 25)
    change = current_petrol - FUEL_BASELINE
    change_pct = (change / FUEL_BASELINE) * 100

    severity = 0.0
    event_type = "fuel_update"
    if change_pct >= 8:
        event_type = "fuel_hike"
        severity = min(1.0, change_pct / 15)
    elif change_pct >= 4:
        event_type = "fuel_increase"
        severity = 0.3

    event = {
        "event_id": str(uuid.uuid4()),
        "source": "fuel_mock",
        "event_type": event_type,
        "location": {"lat": 30.3753, "lng": 69.3451, "name": "Pakistan (National)"},
        "timestamp": datetime.utcnow().isoformat(),
        "severity": round(severity, 2),
        "confidence": 0.90,
        "raw_text": f"Fuel price: Petrol PKR {current_petrol:.0f}/L ({change_pct:+.1f}% from {FUEL_BASELINE:.0f})",
        "structured_data": {
            "petrol_pkr_per_litre": round(current_petrol, 0),
            "change_pct": round(change_pct, 1),
            "baseline": FUEL_BASELINE,
            "mock": True,
        },
        "source_reliability": 0.90,
    }
    stream_client.publish_event(event)
    return [event]
