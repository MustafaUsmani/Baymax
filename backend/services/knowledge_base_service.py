"""
CIRO+ Knowledge Base Seeding Service
Populates the database with:
  - Crisis playbooks (flood, heatwave, accident, protest, etc.)
  - Trigger rules (IF-THEN logic)
  - Source reliability policies
  - App-to-backend interaction mapping rules
  - Output schema definitions
  - Verification rules
"""

from sqlalchemy.orm import Session
from app.models.db_models import AppInteractionRule, KnowledgeBaseEntry
import logging

logger = logging.getLogger(__name__)


def populate_initial_kb(db: Session):
    """Idempotent KB population — only inserts if the tables are empty."""
    if db.query(KnowledgeBaseEntry).first() is not None:
        logger.info("Knowledge base already populated, skipping.")
        return

    logger.info("Populating CIRO+ Knowledge Base...")

    entries = []

    # ══════════════════════════════════════════════════════════════════
    # A. CRISIS PLAYBOOKS
    # ══════════════════════════════════════════════════════════════════
    entries.append(KnowledgeBaseEntry(
        category="playbook", title="Flood Response Playbook", version="1.0",
        tags="flood,water,rescue,drainage",
        content="""\
TRIGGER: Water level sensor > threshold OR multiple social reports of flooding
SEVERITY ESCALATION:
  Low  → Advisory: avoid low-lying areas
  Med  → Reroute traffic, alert residents, pre-position rescue boats
  High → Evacuate affected sector, open shelters, dispatch rescue
  Critical → Full emergency activation, military liaison, helicopter rescue
ACTIONS:
  1. Close flooded roads and reroute traffic via alternate corridors.
  2. Deploy rescue boats to residential low-lying areas.
  3. Alert hospitals for potential casualties and waterborne disease.
  4. Activate water pumps at drainage chokepoints.
  5. Issue public SMS/push alert in English and Urdu.
  6. Open emergency shelters with food, water, blankets.
  7. Monitor weather radar for continued rainfall.
PRECAUTIONS FOR PUBLIC:
  - Move vehicles to higher ground immediately.
  - Stock 48 hours of drinking water and dry food.
  - Avoid walking or driving through standing water.
  - Disconnect electrical appliances in ground-floor areas.
POST-EVENT:
  - Assess infrastructure damage.
  - Check water supply for contamination.
  - Monitor disease outbreak risk (dengue, cholera).
"""))

    entries.append(KnowledgeBaseEntry(
        category="playbook", title="Heatwave Response Playbook", version="1.0",
        tags="heatwave,heat,temperature,health",
        content="""\
TRIGGER: Heat index > 45°C for 2+ consecutive days OR PMD heatwave warning
SEVERITY ESCALATION:
  Low  → Public advisory: hydrate, avoid midday sun
  Med  → Open cooling centres, water distribution
  High → Hospital surge capacity, outdoor labour ban
  Critical → Mass casualty preparation, power grid stress management
ACTIONS:
  1. Issue heatwave advisory via all channels.
  2. Open public cooling centres (mosques, schools, community halls).
  3. Deploy water distribution tankers to vulnerable neighbourhoods.
  4. Restrict outdoor construction and labour 11:00-16:00.
  5. Alert hospitals and EMS for heat stroke cases.
  6. Monitor power grid load — coordinate with IESCO/LESCO for load management.
PRECAUTIONS FOR PUBLIC:
  - Drink water frequently, even if not thirsty.
  - Avoid direct sun exposure between 11:00 and 16:00.
  - Wear light, loose clothing.
  - Check on elderly and chronically ill neighbours.
  - Never leave children or pets in parked vehicles.
"""))

    entries.append(KnowledgeBaseEntry(
        category="playbook", title="Accident Response Playbook", version="1.0",
        tags="accident,traffic,collision,road",
        content="""\
TRIGGER: Emergency call spike for traffic incidents OR social media cluster
ACTIONS:
  1. Dispatch ambulance and police to scene.
  2. Reroute traffic around accident site.
  3. If hazardous materials involved, establish exclusion zone.
  4. Clear debris and reopen road as soon as safe.
  5. Issue travel advisory for affected corridor.
PRECAUTIONS:
  - Use alternate routes displayed in app.
  - Expect 30-60 min delays on affected road.
"""))

    entries.append(KnowledgeBaseEntry(
        category="playbook", title="Protest / Civil Disorder Playbook", version="1.0",
        tags="protest,unrest,political,security",
        content="""\
TRIGGER: GDELT/ACLED conflict spike OR social media mobilisation signals
SEVERITY ESCALATION:
  Low  → Monitor, no public action
  Med  → Travel advisory for affected area, reroute suggestions
  High → Road closures, security deployment, public safety alert
  Critical → Curfew recommendation, avoid all non-essential travel
ACTIONS:
  1. Map protest route and identify affected roads.
  2. Issue travel caution for routes near sensitive zones.
  3. Coordinate with law enforcement for crowd management.
  4. Monitor social media for escalation signals.
  5. Prepare medical teams at nearby hospitals.
PRECAUTIONS:
  - Avoid protest areas and sensitive government zones.
  - Delay non-essential travel.
  - Monitor CIRO+ app for live updates.
"""))

    entries.append(KnowledgeBaseEntry(
        category="playbook", title="Power Outage Response Playbook", version="1.0",
        tags="power,outage,electricity,grid",
        content="""\
TRIGGER: Grid sensor anomaly OR cluster of outage reports
ACTIONS:
  1. Confirm outage extent via grid control centre.
  2. Dispatch repair crews.
  3. Alert hospitals and critical facilities on backup power.
  4. Issue estimated restoration time.
PRECAUTIONS:
  - Charge devices while power is available.
  - Avoid opening refrigerators unnecessarily.
  - Use battery-powered lighting, not candles.
"""))

    entries.append(KnowledgeBaseEntry(
        category="playbook", title="Fuel Hike / Inflation Shock Playbook", version="1.0",
        tags="fuel,inflation,economic,price",
        content="""\
TRIGGER: Fuel price increase > 10% OR CPI spike > 2% month-over-month
ACTIONS:
  1. Issue public advisory on price change.
  2. Monitor for transport strike or protest risk.
  3. Recommend public transport and carpooling.
  4. Flag commuter affordability risk.
  5. Watch for secondary civil unrest.
PRECAUTIONS:
  - Plan trips to minimise fuel usage.
  - Use public transport where available.
  - Stock essential supplies before potential hoarding.
"""))

    entries.append(KnowledgeBaseEntry(
        category="playbook", title="Geopolitical Tension Playbook", version="1.0",
        tags="geopolitical,security,military,border",
        content="""\
TRIGGER: GDELT geopolitical tone score spike OR official security advisory
ACTIONS:
  1. Monitor border and security corridor status.
  2. Issue travel advisory for sensitive zones.
  3. Coordinate with security agencies for intel sharing.
  4. Prepare contingency shelters near border areas.
PRECAUTIONS:
  - Avoid travel near border regions and military zones.
  - Keep emergency supplies ready.
  - Monitor official news channels.
"""))

    entries.append(KnowledgeBaseEntry(
        category="playbook", title="Fire Response Playbook", version="1.0",
        tags="fire,blaze,industrial,wildfire",
        content="""\
TRIGGER: Smoke/fire sensor OR emergency call cluster OR social media
ACTIONS:
  1. Dispatch fire brigade.
  2. Evacuate buildings within 200m radius.
  3. Reroute traffic away from fire zone.
  4. Alert hospitals for burn casualties.
  5. Monitor wind direction for smoke spread.
PRECAUTIONS:
  - Evacuate immediately if fire is nearby.
  - Cover nose/mouth to avoid smoke inhalation.
  - Do not use elevators.
"""))

    entries.append(KnowledgeBaseEntry(
        category="playbook", title="Disease Spike Response Playbook", version="1.0",
        tags="disease,health,epidemic,outbreak",
        content="""\
TRIGGER: Hospital admission spike OR lab-confirmed cluster
ACTIONS:
  1. Activate disease surveillance protocol.
  2. Deploy rapid response team to affected area.
  3. Issue health advisory with symptoms and prevention.
  4. Set up screening points.
  5. Coordinate with WHO/health dept.
PRECAUTIONS:
  - Practice hygiene (handwashing, mask use).
  - Report symptoms early.
  - Avoid crowded areas if outbreak is respiratory.
"""))

    # ══════════════════════════════════════════════════════════════════
    # B. TRIGGER RULES
    # ══════════════════════════════════════════════════════════════════
    trigger_rules = [
        ("IF flood_likelihood > 0.8 THEN reroute_traffic AND issue_alert AND dispatch_rescue", "flood,trigger"),
        ("IF report_unverified AND credibility < 0.4 THEN request_human_review", "verification,trigger"),
        ("IF fuel_hike > 10% AND protest_risk > 0.6 THEN raise_watch_level_to_orange", "economic,trigger"),
        ("IF protest_near_route AND distance < 2km THEN recommend_travel_caution", "protest,trigger"),
        ("IF heatwave_duration > 48h THEN activate_cooling_centres AND ban_outdoor_labour", "heatwave,trigger"),
        ("IF power_outage_duration > 4h THEN alert_hospitals AND deploy_generators", "power,trigger"),
        ("IF multiple_sources_confirm_same_event THEN boost_confidence_by_20pct", "deduplication,trigger"),
        ("IF signal_age > 6h THEN apply_time_decay_factor_0.7", "decay,trigger"),
        ("IF geopolitical_tension_score > 0.8 AND border_proximity < 50km THEN issue_security_alert", "geopolitical,trigger"),
        ("IF disease_cases > threshold AND cluster_detected THEN activate_health_protocol", "disease,trigger"),
    ]
    for content, tags in trigger_rules:
        entries.append(KnowledgeBaseEntry(
            category="trigger", title=content[:80], version="1.0",
            tags=tags, content=content,
        ))

    # ══════════════════════════════════════════════════════════════════
    # C. SOURCE RELIABILITY POLICIES
    # ══════════════════════════════════════════════════════════════════
    entries.append(KnowledgeBaseEntry(
        category="policy", title="Source Reliability Scoring Policy", version="1.0",
        tags="policy,credibility,scoring",
        content="""\
SOURCE RELIABILITY BASELINES:
  Official government / emergency (1122, NDMA, PMD)  → 0.90 – 1.00
  Verified news organisations (Dawn, Geo, ARY)       → 0.75 – 0.90
  International news (Reuters, AP, BBC)              → 0.80 – 0.90
  GDELT / ACLED conflict data                        → 0.75 – 0.85
  Weather APIs (OpenWeatherMap, WeatherAPI)           → 0.85 – 0.95
  Traffic APIs (Mapbox, HERE)                        → 0.80 – 0.90
  Economic APIs (Exchange rates, World Bank)          → 0.85 – 0.95
  Reddit / social media (verified accounts)          → 0.45 – 0.65
  Twitter / X (unverified)                           → 0.35 – 0.55
  Anonymous citizen reports                          → 0.25 – 0.50
  IoT sensors (if calibrated)                        → 0.80 – 0.95

BOOSTING RULES:
  +0.10 if 2+ independent sources confirm the same event
  +0.15 if sensor data corroborates social media report
  +0.05 for each additional corroborating source (max +0.20)

PENALTY RULES:
  -0.10 if location cannot be geocoded
  -0.15 if text contains known spam / rumour patterns
  -0.20 if directly contradicted by official source
"""))

    # ══════════════════════════════════════════════════════════════════
    # D. VERIFICATION RULES
    # ══════════════════════════════════════════════════════════════════
    entries.append(KnowledgeBaseEntry(
        category="policy", title="Human Report Verification Rules", version="1.0",
        tags="policy,verification,human_report",
        content="""\
AUTO-VERIFIED (no human review needed):
  - credibility_score >= 0.85 AND corroborating_signals >= 2 AND no contradictions

PARTIALLY VERIFIED (accepted with caveat):
  - credibility_score >= 0.5 AND at least 1 corroborating signal

HELD FOR REVIEW (requires human confirmation):
  - credibility_score < 0.4
  - contradictions found with official sources
  - should_escalate flag is True

CONTRADICTED (rejected):
  - Official source explicitly denies the event
  - 3+ independent sources contradict the claim

EXPIRY:
  - Unverified reports expire after 6 hours if no corroboration
  - Partially verified reports expire after 24 hours
"""))

    # ══════════════════════════════════════════════════════════════════
    # E. OUTPUT SCHEMA DEFINITIONS
    # ══════════════════════════════════════════════════════════════════
    entries.append(KnowledgeBaseEntry(
        category="schema", title="Standard Event Schema", version="1.0",
        tags="schema,event,output",
        content="""\
{
  "event_id": "uuid",
  "source": "twitter | weather | traffic | user | economic | gdelt",
  "event_type": "flood | protest | heatwave | fuel_hike | ...",
  "location": { "lat": float, "lng": float, "name": string },
  "timestamp": "ISO-8601",
  "severity": 0.0-1.0,
  "confidence": 0.0-1.0,
  "raw_text": "original text",
  "structured_data": {},
  "source_reliability": 0.0-1.0
}
"""))

    entries.append(KnowledgeBaseEntry(
        category="schema", title="Incident Card Schema", version="1.0",
        tags="schema,incident,output",
        content="""\
{
  "id": int,
  "crisis_type": string,
  "title": string,
  "location_text": string,
  "severity": "low | medium | high | critical",
  "confidence": 0.0-1.0,
  "status": "active | resolved | monitoring",
  "affected_radius_m": float,
  "expected_duration_min": int,
  "forecast_summary": string,
  "precaution_summary": string,
  "first_detected_at": "ISO-8601",
  "updated_at": "ISO-8601"
}
"""))

    entries.append(KnowledgeBaseEntry(
        category="schema", title="Forecast Response Schema", version="1.0",
        tags="schema,forecast,output",
        content="""\
{
  "predicted_severity": "low | medium | high | critical",
  "predicted_spread_km": float,
  "predicted_duration_hours": float,
  "peak_time_estimate": string,
  "escalation_probability": 0.0-1.0,
  "cascade_risks": [string],
  "confidence_band": "low | moderate | high",
  "precautions": [{ "action": string, "audience": string, "urgency": string }]
}
"""))

    entries.append(KnowledgeBaseEntry(
        category="schema", title="Simulation Result Schema", version="1.0",
        tags="schema,simulation,output",
        content="""\
{
  "scenario_name": string,
  "before_state": { ... },
  "after_state": { ... },
  "improvement_percentage": float,
  "unintended_consequences": [string],
  "recommendation": "proceed | proceed_with_caution | reconsider"
}
"""))

    entries.append(KnowledgeBaseEntry(
        category="schema", title="Alert Payload Schema", version="1.0",
        tags="schema,alert,communication,output",
        content="""\
{
  "audience": "public | authorities | medical | internal",
  "channel": "sms | push_notification | email | dashboard",
  "message": string,
  "urgency": "flash | urgent | routine",
  "language": "en | ur | both"
}
"""))

    db.add_all(entries)

    # ══════════════════════════════════════════════════════════════════
    # F. APP INTERACTION RULES
    # ══════════════════════════════════════════════════════════════════
    rules = [
        AppInteractionRule(
            user_intent="What is happening near me?",
            backend_endpoint="GET /incidents/nearby?lat=&lon=&radius=",
            agent_chain="DetectionAgent -> SituationAnalysisAgent -> ForecastingAgent -> PrecautionAgent",
            response_schema="IncidentCard[] + Precautions + Forecast",
            notes="Fetches active incidents near the user's GPS location. Returns incident cards, precautions, and forecast summaries.",
        ),
        AppInteractionRule(
            user_intent="I saw flooding here / I want to report an incident",
            backend_endpoint="POST /signals/human-report",
            agent_chain="IngestionAgent -> CredibilityAgent -> VerificationAgent -> DetectionAgent -> full pipeline",
            response_schema="ReportStatus + IncidentCard (if created)",
            notes="Ingests the report, runs NLP extraction (supports Urdu/Roman Urdu), verifies via corroboration, and creates/updates an incident.",
        ),
        AppInteractionRule(
            user_intent="Is it safe to go to [destination]?",
            backend_endpoint="GET /risk/location?lat=&lon=&destination=",
            agent_chain="ForecastingAgent -> PrecautionAgent -> TriggerRecommendationAgent",
            response_schema="RiskAssessment + Precautions + TriggerRecommendations",
            notes="Assesses route safety by checking nearby threats, forecast, and generating travel precautions.",
        ),
        AppInteractionRule(
            user_intent="Any fuel hike or inflation alert?",
            backend_endpoint="GET /situations/forecast?location=national",
            agent_chain="IngestionAgent (Economic) -> ForecastingAgent -> PrecautionAgent",
            response_schema="ForecastResponse + EconomicAlert",
            notes="Monitors economic signals for fuel/price spikes and generates watch-level recommendations.",
        ),
        AppInteractionRule(
            user_intent="Any geopolitical / protest risk near me?",
            backend_endpoint="GET /incidents/nearby?lat=&lon=&radius= (filter: crisis_type=protest,geopolitical_tension)",
            agent_chain="IngestionAgent (Geopolitical) -> DetectionAgent -> ForecastingAgent -> PrecautionAgent",
            response_schema="IncidentCard[] + TravelCaution",
            notes="Checks GDELT/ACLED feeds for unrest and generates travel caution near sensitive zones.",
        ),
        AppInteractionRule(
            user_intent="Show me the forecast for incident #X",
            backend_endpoint="GET /forecast/{incident_id}",
            agent_chain="ForecastingAgent -> PrecautionAgent",
            response_schema="ForecastResponse",
            notes="Returns stored or on-the-fly forecast for a specific incident.",
        ),
        AppInteractionRule(
            user_intent="What precautions should I take?",
            backend_endpoint="GET /precautions/{incident_id}",
            agent_chain="PrecautionAgent",
            response_schema="PrecautionList",
            notes="Returns audience-specific, urgency-ranked precautions for a given incident.",
        ),
        AppInteractionRule(
            user_intent="What actions are being taken?",
            backend_endpoint="GET /actions/{action_id}",
            agent_chain="ActionPlannerAgent (read-only)",
            response_schema="ActionPlan",
            notes="Returns the current action plan and its execution status.",
        ),
        AppInteractionRule(
            user_intent="Show me the simulation / what-if analysis",
            backend_endpoint="GET /simulation/{incident_id}",
            agent_chain="SimulationAgent -> ImpactAssessmentAgent",
            response_schema="SimulationResult",
            notes="Returns before/after simulation results for the incident response.",
        ),
        AppInteractionRule(
            user_intent="What happened with my report?",
            backend_endpoint="GET /verification/reports/{report_id}/status",
            agent_chain="Read-only status check",
            response_schema="ReportStatus",
            notes="Returns the verification status (verified / partially_verified / unverified / contradicted).",
        ),
    ]

    db.add_all(rules)
    db.commit()
    logger.info(f"Knowledge Base populated: {len(entries)} entries + {len(rules)} interaction rules.")
