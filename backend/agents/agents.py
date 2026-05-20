"""
CIRO+ Real LLM-Powered Agent System
All 14 agents use the Google Gemini API with structured JSON output schemas.
Each agent has a dedicated system prompt, Pydantic response schema, and mock fallback.
"""

import os
import json
import logging
import datetime
from typing import Dict, Any, List, Optional
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Gemini SDK bootstrap
# ---------------------------------------------------------------------------
try:
    from google import genai
    from google.genai import types
    GEMINI_AVAILABLE = True
except ImportError:
    GEMINI_AVAILABLE = False
    logger.warning("google-genai not installed. Agents will use mock fallbacks.")

from dotenv import load_dotenv
load_dotenv()

API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY and GEMINI_AVAILABLE:
    logger.warning("GEMINI_API_KEY not set. Agents will use mock fallbacks.")

client = None
if GEMINI_AVAILABLE and API_KEY:
    client = genai.Client(api_key=API_KEY)


# ===========================================================================
# BASE AGENT
# ===========================================================================
class BaseAgent:
    """Base class for all CIRO+ agents."""
    name: str = "BaseAgent"
    model_name: str = "gemini-2.5-flash"
    system_instruction: str = ""

    def _call_gemini(self, prompt: str, schema) -> Dict[str, Any]:
        """Call the Gemini API with structured JSON output."""
        if not client:
            logger.warning(f"{self.name}: Gemini unavailable, using mock fallback.")
            return self._mock_fallback(prompt)
        try:
            response = client.models.generate_content(
                model=self.model_name,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=self.system_instruction,
                    response_mime_type="application/json",
                    response_schema=schema,
                    temperature=0.15,
                ),
            )
            parsed = json.loads(response.text)
            logger.info(f"{self.name}: Gemini returned valid JSON.")
            return parsed
        except Exception as e:
            logger.error(f"{self.name}: Gemini error – {e}. Using mock fallback.")
            return self._mock_fallback(prompt)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        raise NotImplementedError(f"{self.name} has no mock fallback defined.")

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        raise NotImplementedError


# ===========================================================================
# AGENT 1 — INGESTION / NLP EXTRACTION
# ===========================================================================
class IngestionOutput(BaseModel):
    event: str = Field(description="Detected event type: flood, heatwave, protest, accident, fire, road_blockage, power_outage, fuel_hike, inflation_shock, disease_spike, geopolitical_tension, infrastructure_failure, or unknown")
    location: str = Field(description="Extracted geographic location name")
    location_lat: Optional[float] = Field(None, description="Approximate latitude if inferrable")
    location_lng: Optional[float] = Field(None, description="Approximate longitude if inferrable")
    when: str = Field(description="Extracted time reference (e.g. 'now', '2 hours ago', 'tomorrow morning')")
    language_detected: str = Field(description="Language of the input text: en, ur, roman_urdu, hi, unknown")
    normalized_text: str = Field(description="The input text translated/normalized to English")
    confidence: float = Field(description="Confidence of extraction 0.0-1.0")
    reasoning: str = Field(description="Reasoning for the extraction results")

class IngestionAgent(BaseAgent):
    name = "Ingestion Agent"
    system_instruction = (
        "You are a multilingual NLP extraction agent for a crisis intelligence system in Pakistan. "
        "You receive raw text that may be in English, Urdu, Roman Urdu, or Hindi slang. "
        "Your job is to extract: WHAT happened (event type), WHERE (location with coordinates if possible), "
        "WHEN (time reference), and translate/normalize the text to English. "
        "Crisis categories: flood, heatwave, protest, accident, fire, road_blockage, power_outage, "
        "fuel_hike, inflation_shock, disease_spike, geopolitical_tension, infrastructure_failure. "
        "If the text does not clearly describe a crisis, set event to 'unknown' and confidence low."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        raw = input_data.get("raw_text", "")
        source = input_data.get("source", "unknown")
        prompt = (
            f"Extract crisis information from the following text.\n"
            f"Source type: {source}\n"
            f"Text: \"{raw}\"\n"
        )
        return self._call_gemini(prompt, IngestionOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "event": "flood", "location": "G-10 Islamabad",
            "location_lat": 33.6844, "location_lng": 73.0479,
            "when": "now", "language_detected": "roman_urdu",
            "normalized_text": "G-10 is flooded",
            "confidence": 0.72,
            "reasoning": "Keywords matched flood in G-10."
        }


# ===========================================================================
# AGENT 2 — CREDIBILITY SCORING
# ===========================================================================
class CredibilityOutput(BaseModel):
    credibility_score: float = Field(description="Overall credibility 0.0-1.0")
    location_confidence: float = Field(description="Confidence in the stated location 0.0-1.0")
    urgency_score: float = Field(description="How urgent the language sounds 0.0-1.0")
    contradiction_risk: float = Field(description="Risk of this being contradicted by other sources 0.0-1.0")
    duplication_likelihood: float = Field(description="Likelihood this is a duplicate of an existing report 0.0-1.0")
    reasoning: str = Field(description="Short explanation of the scoring")

class CredibilityAgent(BaseAgent):
    name = "Credibility Agent"
    system_instruction = (
        "You are a source-credibility analyst for a crisis intelligence platform. "
        "Score incoming signals on multiple dimensions. Use these baselines: "
        "Official government / emergency lines → 0.9-1.0, "
        "News organizations → 0.7-0.9, "
        "Social media verified accounts → 0.5-0.7, "
        "Anonymous social media → 0.3-0.5, "
        "Anonymous citizen reports → 0.2-0.5. "
        "Also assess urgency language, contradiction risk, and duplication likelihood."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Score the credibility of this crisis signal.\n"
            f"Source: {input_data.get('source', 'unknown')}\n"
            f"Event: {input_data.get('event', 'unknown')}\n"
            f"Location: {input_data.get('location', 'unknown')}\n"
            f"Raw text: \"{input_data.get('raw_text', '')}\"\n"
            f"Normalized text: \"{input_data.get('normalized_text', '')}\"\n"
        )
        return self._call_gemini(prompt, CredibilityOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "credibility_score": 0.65, "location_confidence": 0.7,
            "urgency_score": 0.8, "contradiction_risk": 0.2,
            "duplication_likelihood": 0.1,
            "reasoning": "Social media source with moderate urgency language.",
        }


# ===========================================================================
# AGENT 3 — VERIFICATION
# ===========================================================================
class VerificationOutput(BaseModel):
    verification_status: str = Field(description="One of: verified, partially_verified, unverified, contradicted, needs_more_data")
    corroborating_signals: List[str] = Field(description="Types of signals that could corroborate this report (e.g. 'traffic_spike', 'weather_alert')")
    contradictions_found: List[str] = Field(description="Any contradictions identified")
    should_escalate: bool = Field(description="Whether this should be escalated for human review")
    reasoning: str = Field(description="Explanation of verification decision")

class VerificationAgent(BaseAgent):
    name = "Verification Agent"
    system_instruction = (
        "You are a crisis report verification agent. You receive a signal that has already been "
        "parsed and scored for credibility. Your job is to determine whether the report should be "
        "marked as verified, partially_verified, unverified, contradicted, or needs_more_data. "
        "Consider: Does the event type match the weather/season? Does the location make sense? "
        "Are there logical contradictions? What corroborating data sources would help? "
        "If credibility is below 0.4 or contradictions are found, recommend escalation."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Verify this crisis report.\n"
            f"Event: {input_data.get('event', 'unknown')}\n"
            f"Location: {input_data.get('location', 'unknown')}\n"
            f"Credibility score: {input_data.get('credibility_score', 0.5)}\n"
            f"Urgency: {input_data.get('urgency_score', 0.5)}\n"
            f"Source: {input_data.get('source', 'unknown')}\n"
            f"Normalized text: \"{input_data.get('normalized_text', input_data.get('raw_text', ''))}\"\n"
        )
        return self._call_gemini(prompt, VerificationOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "verification_status": "partially_verified",
            "corroborating_signals": ["traffic_spike", "weather_alert"],
            "contradictions_found": [],
            "should_escalate": False,
            "reasoning": "Report plausible given current weather conditions.",
        }


# ===========================================================================
# AGENT 4 — DETECTION
# ===========================================================================
class DetectionOutput(BaseModel):
    crisis_type: str = Field(description="Classified crisis: flood, heatwave, accident, road_blockage, infrastructure_failure, power_outage, fire, protest, disease_spike, fuel_hike, inflation_shock, geopolitical_tension")
    severity: str = Field(description="One of: low, medium, high, critical")
    confidence: float = Field(description="Detection confidence 0.0-1.0")
    affected_area_description: str = Field(description="Description of the affected geographic area")
    related_crisis_types: List[str] = Field(description="Other crisis types this could cascade into")
    reasoning: str = Field(description="Why this crisis type and severity were chosen")

class DetectionAgent(BaseAgent):
    name = "Detection Agent"
    system_instruction = (
        "You are a crisis detection and classification agent. Based on the ingested, scored, "
        "and verified signal data, you must classify the exact crisis type, assign a severity level, "
        "and identify potential cascade effects (e.g. flood → road_blockage → traffic). "
        "Consider all upstream data: the NLP extraction, credibility scores, and verification status."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Detect and classify this crisis.\n"
            f"Extracted event: {input_data.get('event', 'unknown')}\n"
            f"Location: {input_data.get('location', 'unknown')}\n"
            f"Verification: {input_data.get('verification_status', 'unverified')}\n"
            f"Credibility: {input_data.get('credibility_score', 0.5)}\n"
            f"Normalized text: \"{input_data.get('normalized_text', input_data.get('raw_text', ''))}\"\n"
            f"Corroborating signals: {input_data.get('corroborating_signals', [])}\n"
        )
        return self._call_gemini(prompt, DetectionOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "crisis_type": "flood", "severity": "high", "confidence": 0.88,
            "affected_area_description": "G-10 sector, Islamabad – low-lying residential area",
            "related_crisis_types": ["road_blockage", "power_outage"],
            "reasoning": "Multiple corroborating signals from social media and weather data.",
        }


# ===========================================================================
# AGENT 5 — SITUATION ANALYSIS
# ===========================================================================
class SituationAnalysisOutput(BaseModel):
    summary: str = Field(description="Clear 2-4 sentence situation summary")
    affected_population_estimate: str = Field(description="Estimated number/type of people affected")
    affected_radius_km: float = Field(description="Estimated impact radius in km")
    infrastructure_at_risk: List[str] = Field(description="Infrastructure types at risk (roads, hospitals, schools, power grid, etc.)")
    root_cause_hypothesis: str = Field(description="Most likely cause of the crisis")
    evolving_factors: List[str] = Field(description="Factors that could make the situation worse or better")
    reasoning: str = Field(description="Reasoning behind the situation analysis")

class SituationAnalysisAgent(BaseAgent):
    name = "Situation Analysis Agent"
    system_instruction = (
        "You are a crisis situation analyst. Given a detected incident with its type, severity, "
        "and location, produce a comprehensive situational summary. Estimate the affected population, "
        "impact radius, infrastructure at risk, probable root cause, and factors that could change "
        "the trajectory. Be specific to the Pakistan / South Asia context when possible."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Analyze this crisis situation.\n"
            f"Crisis type: {input_data.get('crisis_type', 'unknown')}\n"
            f"Severity: {input_data.get('severity', 'unknown')}\n"
            f"Location: {input_data.get('location', 'unknown')}\n"
            f"Affected area: {input_data.get('affected_area_description', '')}\n"
            f"Related crises: {input_data.get('related_crisis_types', [])}\n"
            f"Normalized text: \"{input_data.get('normalized_text', '')}\"\n"
        )
        return self._call_gemini(prompt, SituationAnalysisOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "summary": "Urban flooding in G-10 Islamabad following heavy monsoon rains. Roads submerged, vehicles stranded.",
            "affected_population_estimate": "~15,000 residents in G-10 sector",
            "affected_radius_km": 2.5,
            "infrastructure_at_risk": ["roads", "power_grid", "sewage_system"],
            "root_cause_hypothesis": "Blocked drainage combined with above-average monsoon rainfall.",
            "evolving_factors": ["Continued rainfall", "Drainage capacity", "Rescue response speed"],
            "reasoning": "Urban area with known drainage issues and heavy rain reports."
        }


# ===========================================================================
# AGENT 6 — FORECASTING
# ===========================================================================
class ForecastOutput(BaseModel):
    predicted_severity: str = Field(description="Forecast severity: low, medium, high, critical")
    predicted_spread_km: float = Field(description="Expected spread radius in km over next few hours")
    predicted_duration_hours: float = Field(description="Expected duration in hours")
    peak_time_estimate: str = Field(description="When the crisis is expected to peak (relative time)")
    escalation_probability: float = Field(description="Probability of escalation 0.0-1.0")
    cascade_risks: List[str] = Field(description="Other crises this might trigger")
    confidence_band: str = Field(description="Uncertainty descriptor: low, moderate, high")
    reasoning: str = Field(description="Explanation of forecast logic")

class ForecastingAgent(BaseAgent):
    name = "Forecasting Agent"
    system_instruction = (
        "You are a crisis forecasting agent. Based on the detected crisis, its severity, "
        "situation analysis, and any available weather/traffic/economic context, predict how "
        "the crisis will evolve. Estimate spread, duration, peak timing, escalation probability, "
        "and cascade risks. Be realistic and calibrated — avoid over-predicting. "
        "Provide a confidence band for your estimates."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Forecast the evolution of this crisis.\n"
            f"Crisis type: {input_data.get('crisis_type', 'unknown')}\n"
            f"Current severity: {input_data.get('severity', 'unknown')}\n"
            f"Location: {input_data.get('location', 'unknown')}\n"
            f"Situation summary: {input_data.get('summary', '')}\n"
            f"Affected radius: {input_data.get('affected_radius_km', 0)} km\n"
            f"Infrastructure at risk: {input_data.get('infrastructure_at_risk', [])}\n"
            f"Evolving factors: {input_data.get('evolving_factors', [])}\n"
        )
        return self._call_gemini(prompt, ForecastOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "predicted_severity": "high", "predicted_spread_km": 3.0,
            "predicted_duration_hours": 6.0, "peak_time_estimate": "2-3 hours from now",
            "escalation_probability": 0.6,
            "cascade_risks": ["road_blockage", "power_outage"],
            "confidence_band": "moderate",
            "reasoning": "Continued rainfall expected; drainage infrastructure strained.",
        }


# ===========================================================================
# AGENT 7 — PRECAUTION
# ===========================================================================
class PrecautionItem(BaseModel):
    action: str = Field(description="Specific precautionary action")
    audience: str = Field(description="Who this is for: public, commuters, residents, authorities, medical, all")
    urgency: str = Field(description="How urgent: immediate, soon, advisory")
    rationale: str = Field(description="Brief reason for this precaution")

class PrecautionOutput(BaseModel):
    precautions: List[PrecautionItem] = Field(description="Ranked list of precautions, most urgent first")
    general_advisory: str = Field(description="One-line general advisory for the public")
    reasoning: str = Field(description="Reasoning behind the precautions")

class PrecautionAgent(BaseAgent):
    name = "Precaution Agent"
    system_instruction = (
        "You are a precaution and safety advisory agent. Based on the crisis forecast, "
        "generate specific, actionable precautions for different audiences (public, commuters, "
        "residents, authorities, medical teams). Rank by urgency. "
        "Examples: avoid route, leave early, stay indoors, use alternate transport, "
        "secure property, prepare for outage, stock essentials, monitor news."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Generate precaution recommendations for this crisis.\n"
            f"Crisis: {input_data.get('crisis_type', 'unknown')}\n"
            f"Severity: {input_data.get('severity', 'unknown')}\n"
            f"Location: {input_data.get('location', 'unknown')}\n"
            f"Forecast spread: {input_data.get('predicted_spread_km', 0)} km\n"
            f"Forecast duration: {input_data.get('predicted_duration_hours', 0)} hours\n"
            f"Escalation probability: {input_data.get('escalation_probability', 0)}\n"
            f"Cascade risks: {input_data.get('cascade_risks', [])}\n"
        )
        return self._call_gemini(prompt, PrecautionOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "precautions": [
                {"action": "Avoid all roads in G-10", "audience": "commuters", "urgency": "immediate", "rationale": "Roads submerged"},
                {"action": "Move vehicles to higher ground", "audience": "residents", "urgency": "immediate", "rationale": "Water level rising"},
                {"action": "Stock drinking water and food", "audience": "residents", "urgency": "soon", "rationale": "Potential supply disruption"},
            ],
            "general_advisory": "Flooding in G-10 area. Avoid unnecessary travel.",
            "reasoning": "High severity flood requires immediate avoidance and supply prep."
        }


# ===========================================================================
# AGENT 8 — ACTION PLANNER
# ===========================================================================
class ActionItem(BaseModel):
    action_type: str = Field(description="Type: reroute, dispatch, alert, evacuate, shelter, supply, investigate, monitor")
    strategy_name: str = Field(description="Short name for this action strategy")
    description: str = Field(description="Detailed description of what to do")
    priority: str = Field(description="Priority: critical, high, medium, low")
    estimated_impact: str = Field(description="Expected effect of this action")
    trade_offs: str = Field(description="Downsides or risks of this action")

class ActionPlanOutput(BaseModel):
    primary_plan: List[ActionItem] = Field(description="Primary recommended action plan")
    alternative_plan: List[ActionItem] = Field(description="Alternative plan if primary fails")
    multi_crisis_note: str = Field(description="Note on handling if multiple crises are active simultaneously")
    reasoning: str = Field(description="Reasoning for the chosen action plan strategy")

class ActionPlannerAgent(BaseAgent):
    name = "Action Planner Agent"
    system_instruction = (
        "You are a crisis response action planner. Based on the detected crisis, forecast, "
        "and precaution data, create a concrete action plan. Include a primary plan and an "
        "alternative. Consider: rerouting traffic, dispatching rescue/medical, issuing alerts, "
        "evacuations, opening shelters, supply drops, investigations, ongoing monitoring. "
        "Weigh trade-offs. Consider simultaneous crises."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Create an action plan for this crisis.\n"
            f"Crisis: {input_data.get('crisis_type', 'unknown')}, Severity: {input_data.get('severity', 'unknown')}\n"
            f"Location: {input_data.get('location', 'unknown')}\n"
            f"Situation: {input_data.get('summary', '')}\n"
            f"Forecast: spread {input_data.get('predicted_spread_km', 0)} km, "
            f"duration {input_data.get('predicted_duration_hours', 0)} hrs, "
            f"escalation prob {input_data.get('escalation_probability', 0)}\n"
            f"Precautions already issued: {input_data.get('general_advisory', '')}\n"
        )
        return self._call_gemini(prompt, ActionPlanOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "primary_plan": [
                {"action_type": "reroute", "strategy_name": "Divert G-10 Traffic", "description": "Close G-10 entry points and redirect to F-10/H-10 routes", "priority": "critical", "estimated_impact": "Reduce stranded vehicles by 80%", "trade_offs": "Increased congestion on alternate routes"},
                {"action_type": "dispatch", "strategy_name": "Deploy Rescue", "description": "Send 3 rescue boats to G-10/4 low-lying area", "priority": "critical", "estimated_impact": "Extract ~50 stranded residents", "trade_offs": "Diverts resources from other areas"},
            ],
            "alternative_plan": [
                {"action_type": "alert", "strategy_name": "Staged Alert", "description": "Issue progressive alerts if water rises above 1.5m", "priority": "high", "estimated_impact": "Early evacuation", "trade_offs": "Possible false alarm fatigue"},
            ],
            "multi_crisis_note": "If simultaneous heatwave, prioritize flood response but maintain heat shelter availability.",
            "reasoning": "Rerouting is the fastest way to prevent further casualties."
        }


# ===========================================================================
# AGENT 9 — RESOURCE ALLOCATOR
# ===========================================================================
class ResourceAssignment(BaseModel):
    resource_type: str = Field(description="Type of resource: rescue_boat, ambulance, fire_truck, police, shelter, supply_truck, drone, medical_team")
    quantity: int = Field(description="Number of units to deploy")
    deploy_from: str = Field(description="Location or depot to deploy from")
    deploy_to: str = Field(description="Target deployment location")
    estimated_arrival_min: int = Field(description="Estimated arrival time in minutes")
    conflict_note: str = Field(description="Note if this resource is also needed elsewhere")

class ResourceAllocationOutput(BaseModel):
    assignments: List[ResourceAssignment] = Field(description="Resource assignments for this incident")
    total_resources_used: int = Field(description="Total resource units allocated")
    resource_gap: str = Field(description="Any resource shortfalls identified")
    reasoning: str = Field(description="Reasoning for the resource allocation")

class ResourceAllocatorAgent(BaseAgent):
    name = "Resource Allocator Agent"
    system_instruction = (
        "You are a resource allocation agent. Based on the action plan, allocate specific "
        "resources (rescue boats, ambulances, fire trucks, police, shelters, supply trucks, "
        "drones, medical teams). Choose the nearest and most effective resources. "
        "Flag conflicts if resources are needed for simultaneous incidents."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Allocate resources for this crisis response.\n"
            f"Crisis: {input_data.get('crisis_type', 'unknown')}, Location: {input_data.get('location', 'unknown')}\n"
            f"Severity: {input_data.get('severity', 'unknown')}\n"
            f"Action plan: {json.dumps(input_data.get('primary_plan', []))}\n"
            f"Affected radius: {input_data.get('affected_radius_km', 0)} km\n"
            f"Population: {input_data.get('affected_population_estimate', 'unknown')}\n"
        )
        return self._call_gemini(prompt, ResourceAllocationOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "assignments": [
                {"resource_type": "rescue_boat", "quantity": 3, "deploy_from": "NDMA Depot I-9", "deploy_to": "G-10/4", "estimated_arrival_min": 20, "conflict_note": "None"},
                {"resource_type": "ambulance", "quantity": 2, "deploy_from": "PIMS Hospital", "deploy_to": "G-10 Markaz", "estimated_arrival_min": 15, "conflict_note": "None"},
            ],
            "total_resources_used": 5,
            "resource_gap": "Need additional pumps for drainage – not available in current inventory.",
            "reasoning": "Deploying closest available boats and ambulances to minimize ETA."
        }


# ===========================================================================
# AGENT 10 — SIMULATION
# ===========================================================================
class SimulationOutput(BaseModel):
    scenario_name: str = Field(description="Name of this simulation scenario")
    before_state: Dict[str, Any] = Field(description="State before the action (traffic, risk, affected population)")
    after_state: Dict[str, Any] = Field(description="Predicted state after the action")
    improvement_percentage: float = Field(description="Overall improvement metric 0-100%")
    unintended_consequences: List[str] = Field(description="Possible unintended consequences")
    recommendation: str = Field(description="Whether to proceed: proceed, proceed_with_caution, reconsider")
    reasoning: str = Field(description="Reasoning for the simulation results")

class SimulationAgent(BaseAgent):
    name = "Simulation Agent"
    system_instruction = (
        "You are a crisis response simulation agent. Given an action plan and resource allocation, "
        "simulate the before/after outcomes. Estimate the effect on traffic, risk levels, affected "
        "population, resource utilization, and response time. Identify unintended consequences "
        "(e.g. rerouting causes congestion elsewhere). Output a clear recommendation."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Simulate the outcome of this response plan.\n"
            f"Crisis: {input_data.get('crisis_type', 'unknown')}, Location: {input_data.get('location', 'unknown')}\n"
            f"Action plan: {json.dumps(input_data.get('primary_plan', []))}\n"
            f"Resources allocated: {json.dumps(input_data.get('assignments', []))}\n"
            f"Forecast duration: {input_data.get('predicted_duration_hours', 0)} hrs\n"
            f"Current affected radius: {input_data.get('affected_radius_km', 0)} km\n"
        )
        return self._call_gemini(prompt, SimulationOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "scenario_name": "G-10 Flood Reroute + Rescue",
            "before_state": {"traffic_congestion": "severe", "stranded_people": 50, "risk_level": "high"},
            "after_state": {"traffic_congestion": "moderate", "stranded_people": 5, "risk_level": "medium"},
            "improvement_percentage": 72.0,
            "unintended_consequences": ["Increased congestion on F-10 connector", "Ambulance delay on alternate route"],
            "recommendation": "proceed",
            "reasoning": "Significant reduction in stranded people outweighs congestion risk."
        }


# ===========================================================================
# AGENT 11 — IMPACT ASSESSMENT
# ===========================================================================
class ImpactAssessmentOutput(BaseModel):
    benefit_score: float = Field(description="Overall benefit of the response 0.0-1.0")
    cost_estimate: str = Field(description="Estimated operational cost")
    lives_protected_estimate: str = Field(description="Estimated lives/people protected")
    infrastructure_saved: List[str] = Field(description="Infrastructure protected by the response")
    side_effects: List[str] = Field(description="Negative side effects of the response")
    before_after_comparison: str = Field(description="Concise before vs after summary")
    overall_assessment: str = Field(description="One of: highly_effective, effective, partially_effective, ineffective")
    reasoning: str = Field(description="Reasoning for the impact assessment")

class ImpactAssessmentAgent(BaseAgent):
    name = "Impact Assessment Agent"
    system_instruction = (
        "You are a crisis response impact assessor. Evaluate the benefit, cost, side effects, "
        "and overall effectiveness of the planned response. Compare the before and after states "
        "from the simulation. Provide a clear overall assessment rating."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Assess the impact of this crisis response.\n"
            f"Crisis: {input_data.get('crisis_type', 'unknown')}\n"
            f"Simulation result: {input_data.get('scenario_name', '')}\n"
            f"Before: {json.dumps(input_data.get('before_state', {}))}\n"
            f"After: {json.dumps(input_data.get('after_state', {}))}\n"
            f"Improvement: {input_data.get('improvement_percentage', 0)}%\n"
            f"Unintended consequences: {input_data.get('unintended_consequences', [])}\n"
            f"Resources used: {input_data.get('total_resources_used', 0)}\n"
        )
        return self._call_gemini(prompt, ImpactAssessmentOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "benefit_score": 0.78,
            "cost_estimate": "~PKR 2.5M operational cost",
            "lives_protected_estimate": "~45 people rescued or evacuated",
            "infrastructure_saved": ["G-10 power substation", "G-10/4 school"],
            "side_effects": ["Alternate route congestion for ~3 hours"],
            "before_after_comparison": "Before: 50 stranded, severe congestion. After: 5 stranded, moderate congestion.",
            "overall_assessment": "effective",
            "reasoning": "High benefit relative to cost and side effects."
        }


# ===========================================================================
# AGENT 12 — TRIGGER RECOMMENDATION
# ===========================================================================
class TriggerRule(BaseModel):
    condition: str = Field(description="The IF condition")
    action: str = Field(description="The THEN action to trigger")
    priority: str = Field(description="Priority: critical, high, medium, low")
    automated: bool = Field(description="Whether this can be auto-triggered or needs human approval")

class TriggerRecommendationOutput(BaseModel):
    triggers: List[TriggerRule] = Field(description="List of recommended trigger rules")
    watch_level: str = Field(description="Recommended watch level: green, yellow, orange, red")
    next_evaluation_in_min: int = Field(description="When to re-evaluate triggers in minutes")
    reasoning: str = Field(description="Reasoning for the recommended triggers")

class TriggerRecommendationAgent(BaseAgent):
    name = "Trigger Recommendation Agent"
    system_instruction = (
        "You are a trigger logic engine. Based on the current crisis state, forecast, and impact, "
        "recommend what automated or semi-automated actions should be triggered next. "
        "Use IF-THEN rules. Examples: "
        "IF flood likelihood > 0.8 THEN reroute + alert. "
        "IF report unverified THEN request additional verification. "
        "IF fuel hike AND unrest risk THEN raise watch level. "
        "IF protest near major route THEN recommend travel caution. "
        "Set an appropriate watch level (green/yellow/orange/red)."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Recommend trigger rules for this crisis.\n"
            f"Crisis: {input_data.get('crisis_type', 'unknown')}, Severity: {input_data.get('severity', 'unknown')}\n"
            f"Escalation probability: {input_data.get('escalation_probability', 0)}\n"
            f"Verification: {input_data.get('verification_status', 'unknown')}\n"
            f"Impact assessment: {input_data.get('overall_assessment', 'unknown')}\n"
            f"Cascade risks: {input_data.get('cascade_risks', [])}\n"
            f"Simulation recommendation: {input_data.get('recommendation', '')}\n"
        )
        return self._call_gemini(prompt, TriggerRecommendationOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "triggers": [
                {"condition": "Water level rises above 2m", "action": "Trigger evacuation alert", "priority": "critical", "automated": True},
                {"condition": "Forecast shows 4+ hour duration", "action": "Open emergency shelters", "priority": "high", "automated": False},
            ],
            "watch_level": "orange",
            "next_evaluation_in_min": 30,
            "reasoning": "Water levels reaching critical thresholds require immediate automation."
        }


# ===========================================================================
# AGENT 13 — COMMUNICATION
# ===========================================================================
class AlertPayload(BaseModel):
    audience: str = Field(description="Target audience: public, authorities, medical, internal, command_center")
    channel: str = Field(description="Channel: sms, push_notification, email, radio, dashboard, whatsapp")
    message: str = Field(description="The alert message text")
    urgency: str = Field(description="Urgency: flash, urgent, routine")
    language: str = Field(description="Language: en, ur, both")

class CommunicationOutput(BaseModel):
    alerts: List[AlertPayload] = Field(description="List of alert messages for different audiences and channels")
    command_center_summary: str = Field(description="Concise summary for the command center dashboard")
    reasoning: str = Field(description="Reasoning for the communication strategy")

class CommunicationAgent(BaseAgent):
    name = "Communication Agent"
    system_instruction = (
        "You are a crisis communication agent. Generate audience-specific, channel-specific "
        "alert messages. For the public: clear, simple, actionable (in English and Urdu). "
        "For authorities: detailed with coordinates and resource needs. "
        "For the command center: a concise operational summary. "
        "Format messages for SMS (160 chars), push notifications, and dashboard display."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = (
            f"Generate crisis communication messages.\n"
            f"Crisis: {input_data.get('crisis_type', 'unknown')}\n"
            f"Severity: {input_data.get('severity', 'unknown')}\n"
            f"Location: {input_data.get('location', 'unknown')}\n"
            f"Situation: {input_data.get('summary', '')}\n"
            f"Precaution advisory: {input_data.get('general_advisory', '')}\n"
            f"Watch level: {input_data.get('watch_level', 'yellow')}\n"
            f"Key actions: {json.dumps(input_data.get('primary_plan', []))}\n"
        )
        return self._call_gemini(prompt, CommunicationOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "alerts": [
                {"audience": "public", "channel": "sms", "message": "ALERT: Flooding in G-10. Avoid the area. Stay safe.", "urgency": "flash", "language": "en"},
                {"audience": "public", "channel": "sms", "message": "انتباہ: جی-10 میں سیلاب۔ علاقے سے دور رہیں۔", "urgency": "flash", "language": "ur"},
                {"audience": "authorities", "channel": "dashboard", "message": "FLOOD G-10 [33.68,73.05] SEV:HIGH. 3 boats deployed. ETA 20min. Reroute active.", "urgency": "urgent", "language": "en"},
            ],
            "command_center_summary": "Active flood in G-10 Islamabad. Severity HIGH. Rescue deployed. Traffic rerouted. Watch level ORANGE.",
            "reasoning": "Need immediate multi-lingual alerts to prevent further entry into zone."
        }


# ===========================================================================
# AGENT 14 — AUDIT / TRACE
# ===========================================================================
class AgentTraceEntry(BaseModel):
    agent_name: str = Field(description="Name of the agent")
    step_name: str = Field(description="What the agent did")
    input_summary: str = Field(description="Summary of what the agent received")
    decision_summary: str = Field(description="Summary of the agent's key decision")
    output_summary: str = Field(description="Summary of what the agent produced")
    confidence: float = Field(description="Agent's confidence in its output 0.0-1.0")

class AuditOutput(BaseModel):
    trace_entries: List[AgentTraceEntry] = Field(description="Structured trace log of the full agent chain")
    overall_pipeline_confidence: float = Field(description="Aggregate confidence across all agents 0.0-1.0")
    pipeline_duration_note: str = Field(description="Note on processing time and any bottlenecks")
    recommendations_for_improvement: List[str] = Field(description="Suggestions for improving the pipeline")
    reasoning: str = Field(description="Reasoning behind the audit conclusions")

class AuditAgent(BaseAgent):
    name = "Audit / Trace Agent"
    system_instruction = (
        "You are the audit and trace agent. You receive the full accumulated context from all "
        "previous agents in the pipeline. Your job is to produce a structured trace log summarizing "
        "what each agent did, its key decisions, and its confidence level. Also produce an "
        "aggregate pipeline confidence and any recommendations for improvement."
    )

    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        # Collect the agent outputs that have accumulated in input_data
        prompt = (
            f"Generate a structured audit trace for this crisis response pipeline.\n"
            f"Full pipeline context (summarized):\n"
            f"- Event extracted: {input_data.get('event', 'N/A')}\n"
            f"- Location: {input_data.get('location', 'N/A')}\n"
            f"- Credibility: {input_data.get('credibility_score', 'N/A')}\n"
            f"- Verification: {input_data.get('verification_status', 'N/A')}\n"
            f"- Crisis type: {input_data.get('crisis_type', 'N/A')}\n"
            f"- Severity: {input_data.get('severity', 'N/A')}\n"
            f"- Situation: {input_data.get('summary', 'N/A')}\n"
            f"- Forecast spread: {input_data.get('predicted_spread_km', 'N/A')} km\n"
            f"- Forecast duration: {input_data.get('predicted_duration_hours', 'N/A')} hrs\n"
            f"- Escalation prob: {input_data.get('escalation_probability', 'N/A')}\n"
            f"- Precaution advisory: {input_data.get('general_advisory', 'N/A')}\n"
            f"- Actions planned: {len(input_data.get('primary_plan', []))} actions\n"
            f"- Resources allocated: {input_data.get('total_resources_used', 'N/A')} units\n"
            f"- Simulation improvement: {input_data.get('improvement_percentage', 'N/A')}%\n"
            f"- Impact assessment: {input_data.get('overall_assessment', 'N/A')}\n"
            f"- Watch level: {input_data.get('watch_level', 'N/A')}\n"
            f"- Alerts generated: {len(input_data.get('alerts', []))} messages\n"
        )
        return self._call_gemini(prompt, AuditOutput)

    def _mock_fallback(self, prompt: str) -> Dict[str, Any]:
        return {
            "trace_entries": [
                {"agent_name": "Ingestion Agent", "step_name": "NLP Extraction", "input_summary": "Raw Roman Urdu text", "decision_summary": "Classified as flood in G-10", "output_summary": "Event: flood, Location: G-10", "confidence": 0.72},
                {"agent_name": "Credibility Agent", "step_name": "Source Scoring", "input_summary": "Social media signal", "decision_summary": "Moderate credibility", "output_summary": "Score: 0.65", "confidence": 0.65},
                {"agent_name": "Verification Agent", "step_name": "Cross-check", "input_summary": "Parsed flood report", "decision_summary": "Partially verified via weather data", "output_summary": "Status: partially_verified", "confidence": 0.7},
                {"agent_name": "Detection Agent", "step_name": "Classification", "input_summary": "Verified flood signal", "decision_summary": "Flood, severity high", "output_summary": "Crisis: flood, Severity: high", "confidence": 0.88},
                {"agent_name": "Situation Analysis Agent", "step_name": "Impact Assessment", "input_summary": "Detected flood", "decision_summary": "~15k affected, 2.5km radius", "output_summary": "Summary produced", "confidence": 0.75},
                {"agent_name": "Forecasting Agent", "step_name": "Prediction", "input_summary": "Situation data", "decision_summary": "6hr duration, 60% escalation", "output_summary": "Forecast produced", "confidence": 0.7},
            ],
            "overall_pipeline_confidence": 0.72,
            "pipeline_duration_note": "Full pipeline completed in ~8 seconds. No bottlenecks.",
            "recommendations_for_improvement": [
                "Add IoT water-level sensor data for higher verification confidence.",
                "Cross-reference with PMD weather radar for forecast accuracy.",
            ],
            "reasoning": "Pipeline functioned smoothly, but additional sensors would reduce uncertainty."
        }
