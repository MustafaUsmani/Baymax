from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

class Location(BaseModel):
    lat: float
    lon: float

class IncidentBase(BaseModel):
    crisis_type: str
    title: str
    location: Location
    location_text: str
    severity: str
    confidence: float
    status: str
    affected_radius_m: float
    expected_duration_min: int
    forecast_summary: Optional[str] = None
    precaution_summary: Optional[str] = None

class IncidentCreate(IncidentBase):
    pass

class IncidentResponse(IncidentBase):
    id: int
    first_detected_at: datetime
    updated_at: datetime
    class Config:
        orm_mode = True

class StandardEventSchema(BaseModel):
    event_id: str
    source: str
    event_type: str
    location: Dict[str, Any] # {"lat": float, "lng": float, "name": str}
    timestamp: str
    severity: float
    confidence: float
    raw_text: str
    structured_data: Dict[str, Any]
    source_reliability: float

class SignalCreate(BaseModel):
    source_type: str
    source_name: str
    raw_text: str
    language: Optional[str] = "en"
    source_metadata: Optional[Dict[str, Any]] = {}

class HumanReportCreate(BaseModel):
    user_id: Optional[str] = None
    text: str
    location: Location
    attachment_url: Optional[str] = None

class ForecastResponse(BaseModel):
    id: int
    incident_id: int
    forecast_type: str
    predicted_severity: str
    predicted_spread: float
    predicted_duration: int
    uncertainty_band: str
    precaution_recommendations: list
    created_at: datetime
    class Config:
        orm_mode = True

class PrecautionResponse(BaseModel):
    incident_id: int
    precautions: List[str]

class ActionCreate(BaseModel):
    incident_id: int
    action_type: str
    strategy_name: str
    parameters: Dict[str, Any]

class ActionResponse(ActionCreate):
    id: int
    status: str
    expected_effect: Dict[str, Any]
    actual_effect: Optional[Dict[str, Any]] = None
    created_at: datetime
    class Config:
        orm_mode = True

class AgentTraceResponse(BaseModel):
    id: int
    incident_id: Optional[int]
    agent_name: str
    step_name: str
    step_type: str
    input_summary: str
    decision_summary: str
    output_summary: str
    confidence: float
    created_at: datetime
    class Config:
        orm_mode = True

class SimulationRequest(BaseModel):
    incident_id: int
    action_id: int

class SimulationResponse(BaseModel):
    id: int
    incident_id: int
    action_id: int
    before_state: Dict[str, Any]
    after_state: Dict[str, Any]
    side_effects: Dict[str, Any]
    benefit_score: float
    risk_score: float
    created_at: datetime
    class Config:
        orm_mode = True
