from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, JSON, Boolean, Text
from sqlalchemy.orm import relationship
from geoalchemy2 import Geometry
from app.database import Base
import datetime

class Incident(Base):
    __tablename__ = 'incidents'
    
    id = Column(Integer, primary_key=True, index=True)
    crisis_type = Column(String, index=True)
    title = Column(String)
    location = Column(Geometry(geometry_type='POINT', srid=4326))
    location_text = Column(String)
    severity = Column(String) # low, medium, high, critical
    confidence = Column(Float)
    status = Column(String) # active, resolved, monitoring
    first_detected_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
    affected_radius_m = Column(Float)
    expected_duration_min = Column(Integer)
    forecast_summary = Column(Text)
    precaution_summary = Column(Text)
    
    signals = relationship("Signal", back_populates="incident")
    forecasts = relationship("Forecast", back_populates="incident")
    actions = relationship("Action", back_populates="incident")

class StandardEvent(Base):
    __tablename__ = 'standard_events'
    
    event_id = Column(String, primary_key=True, index=True)
    source = Column(String)
    event_type = Column(String, index=True)
    location_lat = Column(Float, nullable=True)
    location_lng = Column(Float, nullable=True)
    location_name = Column(String)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    severity = Column(Float)
    confidence = Column(Float)
    raw_text = Column(Text)
    structured_data = Column(JSON)
    source_reliability = Column(Float)

class Signal(Base):
    __tablename__ = 'signals'
    
    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(Integer, ForeignKey('incidents.id'), nullable=True)
    source_type = Column(String)
    source_name = Column(String)
    raw_text = Column(Text)
    normalized_text = Column(Text)
    geolocation_confidence = Column(Float)
    credibility_score = Column(Float)
    language = Column(String)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    source_metadata = Column(JSON)
    verification_status = Column(String)
    
    incident = relationship("Incident", back_populates="signals")

class HumanReport(Base):
    __tablename__ = 'human_reports'
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, nullable=True)
    incident_id = Column(Integer, ForeignKey('incidents.id'), nullable=True)
    text = Column(Text)
    location = Column(Geometry(geometry_type='POINT', srid=4326))
    attachment_url = Column(String)
    report_status = Column(String)
    verified_by_agent = Column(Boolean, default=False)
    verification_score = Column(Float)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

class Forecast(Base):
    __tablename__ = 'forecasts'
    
    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(Integer, ForeignKey('incidents.id'))
    forecast_type = Column(String)
    predicted_severity = Column(String)
    predicted_spread = Column(Float)
    predicted_duration = Column(Integer)
    uncertainty_band = Column(String)
    precaution_recommendations = Column(JSON)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    incident = relationship("Incident", back_populates="forecasts")

class Action(Base):
    __tablename__ = 'actions'
    
    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(Integer, ForeignKey('incidents.id'))
    action_type = Column(String)
    strategy_name = Column(String)
    parameters = Column(JSON)
    status = Column(String)
    expected_effect = Column(JSON)
    actual_effect = Column(JSON)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    incident = relationship("Incident", back_populates="actions")

class Simulation(Base):
    __tablename__ = 'simulations'
    
    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(Integer, ForeignKey('incidents.id'))
    action_id = Column(Integer, ForeignKey('actions.id'))
    before_state = Column(JSON)
    after_state = Column(JSON)
    side_effects = Column(JSON)
    benefit_score = Column(Float)
    risk_score = Column(Float)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class Resource(Base):
    __tablename__ = 'resources'
    
    id = Column(Integer, primary_key=True, index=True)
    resource_type = Column(String)
    current_location = Column(Geometry(geometry_type='POINT', srid=4326))
    status = Column(String)
    available_count = Column(Integer)
    last_assigned_incident = Column(Integer, nullable=True)
    metadata_json = Column(JSON)

class Alert(Base):
    __tablename__ = 'alerts'
    
    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(Integer, ForeignKey('incidents.id'))
    audience_type = Column(String)
    message = Column(Text)
    channel = Column(String)
    status = Column(String)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    sent_at = Column(DateTime, nullable=True)

class AgentTrace(Base):
    __tablename__ = 'agent_traces'
    
    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(Integer, ForeignKey('incidents.id'), nullable=True)
    agent_name = Column(String)
    step_name = Column(String)
    step_type = Column(String)
    input_summary = Column(Text)
    decision_summary = Column(Text)
    output_summary = Column(Text)
    confidence = Column(Float)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class KnowledgeBaseEntry(Base):
    __tablename__ = 'knowledge_base_entries'
    
    id = Column(Integer, primary_key=True, index=True)
    category = Column(String)
    title = Column(String)
    content = Column(Text)
    tags = Column(String)
    version = Column(String)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

class AppInteractionRule(Base):
    __tablename__ = 'app_interaction_rules'
    
    id = Column(Integer, primary_key=True, index=True)
    user_intent = Column(String)
    backend_endpoint = Column(String)
    agent_chain = Column(String)
    response_schema = Column(String)
    notes = Column(Text)
