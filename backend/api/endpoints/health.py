"""CIRO+ Health & System Status Endpoints."""

import os
from fastapi import APIRouter
from dotenv import load_dotenv

load_dotenv()

router = APIRouter()


@router.get("/")
def health():
    return {"status": "healthy"}


@router.get("/ready")
def readiness():
    """Check all dependencies."""
    checks = {}

    # Gemini
    checks["gemini"] = "configured" if os.environ.get("GEMINI_API_KEY") else "missing_key"

    # Weather APIs
    checks["openweathermap"] = "configured" if os.environ.get("OPENWEATHERMAP_API_KEY") else "missing_key (will use mock)"
    checks["weatherapi"] = "configured" if os.environ.get("WEATHERAPI_KEY") else "missing_key (will use mock)"

    # News
    checks["newsapi"] = "configured" if os.environ.get("NEWSAPI_KEY") else "missing_key (will use GDELT+RSS)"

    # Traffic
    checks["tomtom"] = "configured" if os.environ.get("TOMTOM_API_KEY") else "missing_key (will use mock)"
    checks["openrouteservice"] = "configured" if os.environ.get("OPENROUTESERVICE_API_KEY") else "missing_key (will use mock)"

    # Free APIs (no key needed)
    checks["gdelt"] = "available (no key needed)"
    checks["google_news_rss"] = "available (no key needed)"
    checks["reddit_public"] = "available (no key needed)"
    checks["exchange_rate_api"] = "available (no key needed)"
    checks["worldbank_api"] = "available (no key needed)"
    checks["openaq"] = "configured" if os.environ.get("OPENAQ_API_KEY") else "available (limited without key)"

    # Infrastructure
    try:
        import redis
        r = redis.Redis(host=os.environ.get("REDIS_HOST", "localhost"))
        r.ping()
        checks["redis"] = "connected"
    except Exception:
        checks["redis"] = "unavailable"

    try:
        from app.database import engine
        with engine.connect() as conn:
            conn.execute("SELECT 1")
        checks["postgresql"] = "connected"
    except Exception:
        checks["postgresql"] = "unavailable"

    all_ok = all(v not in ("unavailable",) for v in checks.values())

    return {
        "status": "ready" if all_ok else "degraded",
        "services": checks,
        "data_sources": {
            "real_apis": {
                "social": ["Reddit (public)", "GDELT DOC (free)", "Google News RSS (free)", "NewsAPI (key)"],
                "weather": ["OpenWeatherMap (key)", "WeatherAPI (key)"],
                "traffic": ["TomTom (key)", "OpenRouteService (key)"],
                "economic": ["Open Exchange Rates (free)", "World Bank (free)"],
                "geopolitical": ["GDELT DOC (free)", "GDELT GEO (free)"],
                "iot": ["OpenAQ (free/key)"],
            },
            "mock_fallbacks": [
                "Water level sensors", "Power grid status",
                "Fuel prices", "1122 Emergency calls",
            ],
        },
    }
