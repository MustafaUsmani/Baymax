"""
CIRO+ Social & News Ingestor
Real API integrations:
  - Reddit API (public JSON, no auth for read)
  - NewsAPI (free tier — requires key)
  - GDELT DOC API (completely free, no key)
  - Google News RSS (free, no key)
Fallback: realistic mock social posts
"""

import os
import uuid
import logging
import time
from datetime import datetime
from typing import List, Dict, Any, Optional

import httpx
import feedparser
from dotenv import load_dotenv

from app.services.redis_streams import stream_client

load_dotenv()
logger = logging.getLogger(__name__)

NEWSAPI_KEY = os.environ.get("NEWSAPI_KEY")
REDDIT_USER_AGENT = os.environ.get("REDDIT_USER_AGENT", "CIRO_Bot/1.0")

TIMEOUT = httpx.Timeout(15.0)


# ══════════════════════════════════════════════════════════════════════
# 1. REDDIT  (public JSON — no auth required for read-only)
# ══════════════════════════════════════════════════════════════════════
def fetch_reddit_posts(
    subreddits: List[str] = None,
    limit: int = 10,
) -> List[Dict[str, Any]]:
    """Fetch latest posts from crisis-related subreddits."""
    subreddits = subreddits or ["islamabad", "pakistan", "worldnews", "weather"]
    events = []

    for sub in subreddits:
        url = f"https://www.reddit.com/r/{sub}/new.json?limit={limit}"
        try:
            resp = httpx.get(url, headers={"User-Agent": REDDIT_USER_AGENT}, timeout=TIMEOUT)
            resp.raise_for_status()
            data = resp.json()

            for post in data.get("data", {}).get("children", []):
                p = post["data"]
                event = _build_event(
                    source="reddit",
                    raw_text=f"{p.get('title', '')} {p.get('selftext', '')[:300]}",
                    source_reliability=0.50,
                    structured_data={
                        "subreddit": sub,
                        "author": p.get("author"),
                        "score": p.get("score", 0),
                        "url": p.get("url"),
                        "permalink": f"https://reddit.com{p.get('permalink', '')}",
                    },
                )
                events.append(event)
                stream_client.publish_event(event)

            logger.info(f"Reddit r/{sub}: fetched {len(data.get('data', {}).get('children', []))} posts")

        except Exception as e:
            logger.warning(f"Reddit r/{sub} failed: {e} — using mock fallback")
            events.extend(_mock_social_posts(source="reddit_mock", count=3))

    return events


# ══════════════════════════════════════════════════════════════════════
# 2. NEWSAPI  (free tier — 100 requests/day)
# ══════════════════════════════════════════════════════════════════════
def fetch_newsapi(
    query: str = "Pakistan crisis OR flood OR protest OR accident",
    page_size: int = 10,
) -> List[Dict[str, Any]]:
    """Fetch news articles from NewsAPI."""
    if not NEWSAPI_KEY:
        logger.warning("NEWSAPI_KEY not set — using mock fallback")
        return _mock_social_posts(source="newsapi_mock", count=5)

    url = "https://newsapi.org/v2/everything"
    params = {
        "q": query,
        "pageSize": page_size,
        "sortBy": "publishedAt",
        "language": "en",
        "apiKey": NEWSAPI_KEY,
    }
    events = []

    try:
        resp = httpx.get(url, params=params, timeout=TIMEOUT)
        resp.raise_for_status()
        articles = resp.json().get("articles", [])

        for art in articles:
            event = _build_event(
                source="newsapi",
                raw_text=f"{art.get('title', '')}. {art.get('description', '')}",
                source_reliability=0.80,
                structured_data={
                    "source_name": art.get("source", {}).get("name"),
                    "author": art.get("author"),
                    "url": art.get("url"),
                    "published_at": art.get("publishedAt"),
                    "image_url": art.get("urlToImage"),
                },
            )
            events.append(event)
            stream_client.publish_event(event)

        logger.info(f"NewsAPI: fetched {len(articles)} articles")

    except Exception as e:
        logger.warning(f"NewsAPI failed: {e} — using mock fallback")
        events.extend(_mock_social_posts(source="newsapi_mock", count=5))

    return events


# ══════════════════════════════════════════════════════════════════════
# 3. GDELT DOC API  (completely free, no key needed)
# ══════════════════════════════════════════════════════════════════════
def fetch_gdelt_news(
    query: str = "Pakistan flood OR protest OR heatwave OR accident",
    max_records: int = 10,
) -> List[Dict[str, Any]]:
    """Fetch global news from the GDELT DOC 2.0 API (free, no key)."""
    url = "https://api.gdeltproject.org/api/v2/doc/doc"
    params = {
        "query": query,
        "mode": "ArtList",
        "maxrecords": max_records,
        "format": "json",
        "sort": "DateDesc",
    }
    events = []

    try:
        resp = httpx.get(url, params=params, timeout=TIMEOUT)
        resp.raise_for_status()
        data = resp.json()
        articles = data.get("articles", [])

        for art in articles:
            event = _build_event(
                source="gdelt",
                raw_text=f"{art.get('title', '')}",
                source_reliability=0.80,
                structured_data={
                    "url": art.get("url"),
                    "domain": art.get("domain"),
                    "language": art.get("language"),
                    "seendate": art.get("seendate"),
                    "socialimage": art.get("socialimage"),
                    "tone": art.get("tone"),
                },
            )
            events.append(event)
            stream_client.publish_event(event)

        logger.info(f"GDELT: fetched {len(articles)} articles")

    except Exception as e:
        logger.warning(f"GDELT failed: {e} — using mock fallback")
        events.extend(_mock_social_posts(source="gdelt_mock", count=5))

    return events


# ══════════════════════════════════════════════════════════════════════
# 4. GOOGLE NEWS RSS  (free, no key)
# ══════════════════════════════════════════════════════════════════════
def fetch_google_news_rss(
    query: str = "Pakistan crisis",
    max_items: int = 10,
) -> List[Dict[str, Any]]:
    """Parse Google News RSS feed."""
    url = f"https://news.google.com/rss/search?q={query}&hl=en-PK&gl=PK&ceid=PK:en"
    events = []

    try:
        feed = feedparser.parse(url)

        for entry in feed.entries[:max_items]:
            event = _build_event(
                source="google_news_rss",
                raw_text=entry.get("title", ""),
                source_reliability=0.78,
                structured_data={
                    "link": entry.get("link"),
                    "published": entry.get("published"),
                    "source": entry.get("source", {}).get("title") if hasattr(entry, "source") else None,
                },
            )
            events.append(event)
            stream_client.publish_event(event)

        logger.info(f"Google News RSS: fetched {len(feed.entries[:max_items])} items")

    except Exception as e:
        logger.warning(f"Google News RSS failed: {e} — using mock fallback")
        events.extend(_mock_social_posts(source="rss_mock", count=3))

    return events


# ══════════════════════════════════════════════════════════════════════
# 5. SINGLE TEXT INGESTION  (for direct API calls from the app)
# ══════════════════════════════════════════════════════════════════════
def ingest_social_text(raw_text: str, source: str = "twitter") -> Dict[str, Any]:
    """Ingest a single social/citizen text and publish to stream."""
    event = _build_event(
        source=source,
        raw_text=raw_text,
        source_reliability=0.50 if source in ("twitter", "reddit") else 0.40,
    )
    stream_client.publish_event(event)
    return event


# ══════════════════════════════════════════════════════════════════════
# 6. FETCH ALL SOURCES  (convenience function)
# ══════════════════════════════════════════════════════════════════════
def fetch_all_social_sources() -> List[Dict[str, Any]]:
    """Run all social/news ingestors and return all events."""
    all_events = []
    all_events.extend(fetch_reddit_posts())
    all_events.extend(fetch_newsapi())
    all_events.extend(fetch_gdelt_news())
    all_events.extend(fetch_google_news_rss())
    logger.info(f"Social ingestor: total {len(all_events)} events ingested")
    return all_events


# ══════════════════════════════════════════════════════════════════════
# MOCK FALLBACK
# ══════════════════════════════════════════════════════════════════════
def _mock_social_posts(source: str = "mock_social", count: int = 5) -> List[Dict[str, Any]]:
    """Generate realistic mock social posts for Pakistan crisis scenarios."""
    mock_texts = [
        "G-10 mein pani bhar gaya hai, roads blocked — rescue needed",
        "Massive traffic jam on Kashmir Highway near Faizabad due to accident",
        "Protests starting near D-Chowk Islamabad, police deployed in large numbers",
        "Bijli nahi aa rahi 4 ghante se — F-8 Islamabad power outage continues",
        "Petrol prices badh gayi phir se — 15 rupees ka izafa aaj se",
        "Fire reported at I-9 Industrial Area warehouse, multiple fire engines responding",
        "Heatwave warning issued for Punjab — temperatures expected to cross 48°C",
        "Heavy rainfall expected in Islamabad/Rawalpindi — NDMA issues flood alert",
        "Road blockage at GT Road Rawalpindi due to water pipeline burst",
        "Gas leak reported near Blue Area, buildings being evacuated",
    ]
    events = []
    for text in mock_texts[:count]:
        event = _build_event(source=source, raw_text=text, source_reliability=0.50)
        events.append(event)
        stream_client.publish_event(event)
    return events


# ══════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════
def _build_event(
    source: str,
    raw_text: str,
    source_reliability: float,
    structured_data: Optional[Dict] = None,
) -> Dict[str, Any]:
    return {
        "event_id": str(uuid.uuid4()),
        "source": source,
        "event_type": "unknown",
        "location": {"lat": 0.0, "lng": 0.0, "name": ""},
        "timestamp": datetime.utcnow().isoformat(),
        "severity": 0.0,
        "confidence": 0.0,
        "raw_text": raw_text.strip(),
        "structured_data": structured_data or {},
        "source_reliability": source_reliability,
    }
