"""
CIRO+ Incident Response Workflow
Full 14-agent pipeline orchestrated by the Antigravity Orchestrator.
Supports sequential, parallel, and checkpoint flows with DB persistence.
"""

import logging
import time
from typing import Dict, Any, Optional
from sqlalchemy.orm import Session

from app.agents.orchestrator import orchestrator
from app.agents.agents import (
    IngestionAgent, CredibilityAgent, VerificationAgent, DetectionAgent,
    SituationAnalysisAgent, ForecastingAgent, PrecautionAgent, ActionPlannerAgent,
    ResourceAllocatorAgent, SimulationAgent, ImpactAssessmentAgent,
    TriggerRecommendationAgent, CommunicationAgent, AuditAgent,
)

logger = logging.getLogger(__name__)


def run_incident_workflow(
    initial_signal: Dict[str, Any],
    db: Optional[Session] = None,
    incident_id: Optional[int] = None,
) -> Dict[str, Any]:
    """
    Run the full 14-agent crisis response pipeline.

    Flow:
      Phase 1 (Sequential): Ingest → Credibility → Verification
      Checkpoint: Hold for review if low confidence / contradicted
      Phase 2 (Sequential): Detection → Situation Analysis → Forecasting → Precaution
      Phase 3 (Parallel):   Action Planner ∥ Resource Allocator ∥ Trigger Recommendation
      Phase 4 (Sequential): Simulation → Impact Assessment → Communication → Audit

    Returns the fully accumulated context dict with all agent outputs.
    """
    pipeline_start = time.time()
    orchestrator.clear_traces()

    # ── Phase 1: Ingestion & Verification ─────────────────────────────
    logger.info("═══ Phase 1: Ingestion & Verification ═══")
    context = orchestrator.run_sequential(
        agents=[IngestionAgent(), CredibilityAgent(), VerificationAgent()],
        initial_input=initial_signal,
        db=db,
        incident_id=incident_id,
    )

    # ── Checkpoint ────────────────────────────────────────────────────
    if not orchestrator.human_in_the_loop_checkpoint(context):
        context["pipeline_status"] = "held_for_review"
        context["pipeline_traces"] = orchestrator.get_traces()
        return context

    # ── Phase 2: Detection & Forecasting ──────────────────────────────
    logger.info("═══ Phase 2: Detection & Forecasting ═══")
    context = orchestrator.run_sequential(
        agents=[DetectionAgent(), SituationAnalysisAgent(), ForecastingAgent(), PrecautionAgent()],
        initial_input=context,
        db=db,
        incident_id=incident_id,
    )

    # ── Phase 3: Parallel Planning ────────────────────────────────────
    logger.info("═══ Phase 3: Parallel Planning ═══")
    parallel_results = orchestrator.run_parallel(
        agents=[ActionPlannerAgent(), ResourceAllocatorAgent(), TriggerRecommendationAgent()],
        input_data=context,
        db=db,
        incident_id=incident_id,
    )
    context.update(parallel_results)

    # ── Phase 4: Simulation, Impact, Communication, Audit ─────────────
    logger.info("═══ Phase 4: Simulation & Finalization ═══")
    context = orchestrator.run_sequential(
        agents=[SimulationAgent(), ImpactAssessmentAgent(), CommunicationAgent(), AuditAgent()],
        initial_input=context,
        db=db,
        incident_id=incident_id,
    )

    # ── Pipeline metadata ─────────────────────────────────────────────
    elapsed = round(time.time() - pipeline_start, 2)
    context["pipeline_status"] = "completed"
    context["pipeline_elapsed_seconds"] = elapsed
    context["pipeline_traces"] = orchestrator.get_traces()
    logger.info(f"═══ Pipeline completed in {elapsed}s ═══")

    return context


def run_verification_only(
    signal: Dict[str, Any],
    db: Optional[Session] = None,
) -> Dict[str, Any]:
    """Short pipeline for verifying a single human report."""
    orchestrator.clear_traces()
    context = orchestrator.run_sequential(
        agents=[IngestionAgent(), CredibilityAgent(), VerificationAgent()],
        initial_input=signal,
        db=db,
    )
    context["pipeline_traces"] = orchestrator.get_traces()
    return context


def run_forecast_only(
    signal: Dict[str, Any],
    db: Optional[Session] = None,
) -> Dict[str, Any]:
    """Short pipeline for forecasting an already-detected incident."""
    orchestrator.clear_traces()
    context = orchestrator.run_sequential(
        agents=[ForecastingAgent(), PrecautionAgent()],
        initial_input=signal,
        db=db,
    )
    context["pipeline_traces"] = orchestrator.get_traces()
    return context
