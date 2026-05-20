import redis
import json
import logging
import os

logger = logging.getLogger(__name__)

REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))

class RedisStreamClient:
    def __init__(self):
        self.redis = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)
        self.stream_name = "events_stream"

    def publish_event(self, event_data: dict):
        try:
            # Redis streams require dict with string values
            payload = {"data": json.dumps(event_data)}
            message_id = self.redis.xadd(self.stream_name, payload)
            logger.info(f"Published event to stream {self.stream_name}: {message_id}")
            return message_id
        except Exception as e:
            logger.error(f"Failed to publish to Redis stream: {e}")
            return None

    def consume_events(self, consumer_group="ingestion_group", consumer_name="worker_1", count=10):
        try:
            # Ensure group exists
            try:
                self.redis.xgroup_create(self.stream_name, consumer_group, id="0", mkstream=True)
            except redis.exceptions.ResponseError:
                pass # Group already exists
                
            messages = self.redis.xreadgroup(
                groupname=consumer_group,
                consumername=consumer_name,
                streams={self.stream_name: ">"},
                count=count,
                block=2000
            )
            
            parsed_messages = []
            for stream, stream_msgs in messages:
                for message_id, msg_data in stream_msgs:
                    parsed_messages.append({
                        "id": message_id,
                        "data": json.loads(msg_data["data"])
                    })
                    
            return parsed_messages
        except Exception as e:
            logger.error(f"Failed to consume from Redis stream: {e}")
            return []
            
    def ack_message(self, consumer_group: str, message_id: str):
        self.redis.xack(self.stream_name, consumer_group, message_id)

stream_client = RedisStreamClient()
