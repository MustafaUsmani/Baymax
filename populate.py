import sys
import os

# Add root CIRO directory to path so 'app' is found
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app.database import SessionLocal, Base, engine
from app.models.schemas import SignalCreate
from app.services.signal_ingestion import ingest_and_process_signal
from app.services.ingestion_service.social_ingestor import fetch_all_social_sources
from app.services.ingestion_service.weather_ingestor import fetch_all_weather
from app.services.ingestion_service.traffic_ingestor import fetch_all_traffic
from app.services.ingestion_service.emergency_mock_generator import generate_emergency_batch

import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def populate_db():
    # Ensure tables exist
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    
    try:
        # 1. Fetch Events
        logger.info("Fetching social sources...")
        social_events = fetch_all_social_sources()
        
        logger.info("Fetching weather sources...")
        weather_events = fetch_all_weather()
        
        logger.info("Fetching traffic sources...")
        traffic_events = fetch_all_traffic()
        
        logger.info("Generating emergency mock data...")
        emergency_events = generate_emergency_batch(count=3)
        
        all_events = social_events + weather_events + traffic_events + emergency_events
        
        logger.info(f"Total events fetched: {len(all_events)}")
        
        import random
        random.shuffle(all_events)
        sample_events = all_events[:8]
        
        for idx, event in enumerate(sample_events):
            logger.info(f"Processing event {idx + 1}/8: {event.get('source')} - {event.get('raw_text')[:50]}...")
            signal_data = SignalCreate(
                source_type=event.get("source", "unknown"),
                source_name=event.get("source", "unknown"),
                raw_text=event.get("raw_text", ""),
                language="en",
                source_metadata=event.get("structured_data", {})
            )
            
            # Pass to full pipeline
            try:
                result = ingest_and_process_signal(signal_data, db)
                logger.info(f"Successfully processed event. Created Incident ID: {result.get('incident_id')}")
            except Exception as e:
                logger.error(f"Error processing event: {e}")
                
    finally:
        db.close()

if __name__ == "__main__":
    populate_db()
