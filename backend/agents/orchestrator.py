"""
CIRO+ Antigravity Orchestrator
Production-grade multi-agent orchestration layer with:
- Sequential and parallel agent execution
- Real database trace logging (AgentTrace table)
- Human-in-the-loop checkpoints
- Retry logic with fallback
- Timing instrumentation
"""

import logging
import time
import datetime
from typing import Dict, Any, List, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


class AntigravityOrchestrator:
    """
    Google Antigravity-style orchestration layer for CIRO+ agents.
    Coordinates sequential flows, parallel branches, checkpoints, and DB trace logging.
    """

    def __init__(self):
        self.trace_logs: List[Dict[str, Any]] = []
        self._executor = ThreadPoolExecutor(max_workers=6)

    # ------------------------------------------------------------------
    # SEQUENTIAL EXECUTION
    # ------------------------------------------------------------------
    def run_sequential(
        self,
        agents: List[Any],
        initial_input: Dict[str, Any],
        db: Optional[Session] = None,
        incident_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Run agents one after another.  Each agent receives the accumulated
        context dict and its output is merged back into that dict before
        the next agent runs.
        """
        context = dict(initial_input)
        for agent in agents:
            start = time.time()
            logger.info(f"▶ Orchestrator: Starting {agent.name}")

            try:
                result = agent.execute(context)
            except Exception as e:
                logger.error(f"✖ {agent.name} failed: {e}")
                result = {"error": str(e)}

            elapsed = round(time.time() - start, 3)
            logger.info(f"✔ {agent.name} completed in {elapsed}s")

            self._record_trace(
                agent_name=agent.name,
                step_name=f"sequential_run",
                input_data=context,
                output_data=result,
                confidence=result.get("confidence", result.get("credibility_score", 0.0)),
                elapsed_s=elapsed,
                db=db,
                incident_id=incident_id,
            )
            context.update(result)

        return context

    # ------------------------------------------------------------------
    # PARALLEL EXECUTION
    # ------------------------------------------------------------------
    def run_parallel(
        self,
        agents: List[Any],
        input_data: Dict[str, Any],
        db: Optional[Session] = None,
        incident_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Run agents concurrently via a thread pool.
        Each agent gets the same snapshot of `input_data`.
        Results are merged into a single dict.
        """
        merged: Dict[str, Any] = {}
        futures = {}

        for agent in agents:
            # Give each agent a frozen copy so they don't interfere
            snapshot = dict(input_data)
            futures[self._executor.submit(agent.execute, snapshot)] = agent

        for future in as_completed(futures):
            agent = futures[future]
            start = time.time()
            try:
                result = future.result(timeout=60)
            except Exception as e:
                logger.error(f"✖ {agent.name} parallel failed: {e}")
                result = {"error": str(e)}

            elapsed = round(time.time() - start, 3)
            logger.info(f"✔ {agent.name} (parallel) completed in {elapsed}s")

            self._record_trace(
                agent_name=agent.name,
                step_name="parallel_run",
                input_data=input_data,
                output_data=result,
                confidence=result.get("confidence", 0.0),
                elapsed_s=elapsed,
                db=db,
                incident_id=incident_id,
            )
            merged.update(result)

        return merged

    # ------------------------------------------------------------------
    # HUMAN-IN-THE-LOOP CHECKPOINT
    # ------------------------------------------------------------------
    def human_in_the_loop_checkpoint(
        self,
        data: Dict[str, Any],
        confidence_threshold: float = 0.4,
    ) -> bool:
        """
        Returns False (hold for review) when:
        - confidence is below threshold
        - verification_status is 'contradicted'
        - should_escalate flag is True
        """
        confidence = data.get("confidence", data.get("credibility_score", 1.0))
        contradicted = data.get("verification_status") == "contradicted"
        escalate = data.get("should_escalate", False)

        if confidence < confidence_threshold or contradicted or escalate:
            logger.warning(
                f"⚠ CHECKPOINT: Holding for human review. "
                f"confidence={confidence}, contradicted={contradicted}, escalate={escalate}"
            )
            return False

        logger.info(f"✔ CHECKPOINT: Passed (confidence={confidence})")
        return True

    # ------------------------------------------------------------------
    # RETRY WRAPPER
    # ------------------------------------------------------------------
    def run_with_retry(
        self,
        agent: Any,
        input_data: Dict[str, Any],
        max_retries: int = 2,
        db: Optional[Session] = None,
        incident_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Run a single agent with retry on failure."""
        for attempt in range(1, max_retries + 1):
            try:
                start = time.time()
                result = agent.execute(input_data)
                elapsed = round(time.time() - start, 3)
                self._record_trace(
                    agent_name=agent.name,
                    step_name=f"retry_attempt_{attempt}",
                    input_data=input_data,
                    output_data=result,
                    confidence=result.get("confidence", 0.0),
                    elapsed_s=elapsed,
                    db=db,
                    incident_id=incident_id,
                )
                return result
            except Exception as e:
                logger.warning(f"⟳ {agent.name} attempt {attempt}/{max_retries} failed: {e}")
                if attempt == max_retries:
                    return {"error": str(e), "agent": agent.name}

    # ------------------------------------------------------------------
    # TRACE LOGGING
    # ------------------------------------------------------------------
    def _record_trace(
        self,
        agent_name: str,
        step_name: str,
        input_data: Dict,
        output_data: Dict,
        confidence: float,
        elapsed_s: float,
        db: Optional[Session] = None,
        incident_id: Optional[int] = None,
    ):
        """Write structured trace to in-memory list and optionally to the DB."""
        trace = {
            "agent": agent_name,
            "step": step_name,
            "input_summary": _summarize(input_data, 300),
            "decision_summary": _summarize(output_data, 300),
            "confidence": confidence,
            "elapsed_s": elapsed_s,
            "timestamp": datetime.datetime.utcnow().isoformat(),
        }
        self.trace_logs.append(trace)

        if db is not None:
            try:
                from app.models.db_models import AgentTrace

                db_trace = AgentTrace(
                    incident_id=incident_id,
                    agent_name=agent_name,
                    step_name=step_name,
                    step_type="llm_call",
                    input_summary=trace["input_summary"],
                    decision_summary=trace["decision_summary"],
                    output_summary=_summarize(output_data, 500),
                    confidence=confidence,
                )
                db.add(db_trace)
                db.commit()
            except Exception as e:
                logger.error(f"Failed to write trace to DB: {e}")

    def get_traces(self) -> List[Dict[str, Any]]:
        """Return all in-memory traces."""
        return list(self.trace_logs)

    def clear_traces(self):
        """Reset in-memory trace buffer."""
        self.trace_logs.clear()


def _summarize(data: Dict, max_len: int = 300) -> str:
    """Create a truncated string summary of a dict."""
    try:
        import json
        s = json.dumps(data, default=str)
    except Exception:
        s = str(data)
    return s[:max_len]


# Singleton
orchestrator = AntigravityOrchestrator()
