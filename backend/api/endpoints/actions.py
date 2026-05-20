"""CIRO+ Action, Simulation & Execution Endpoints — real DB + agents."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.schemas import ActionCreate, SimulationRequest
from app.models.db_models import Action, Simulation, Incident

router = APIRouter()


@router.post("/plan")
def plan_action(req: ActionCreate, db: Session = Depends(get_db)):
    """Use the ActionPlanner agent to generate a plan, then persist it."""
    incident = db.query(Incident).filter(Incident.id == req.incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    from app.agents.agents import ActionPlannerAgent
    agent = ActionPlannerAgent()
    result = agent.execute({
        "crisis_type": incident.crisis_type,
        "severity": incident.severity,
        "location": incident.location_text,
        "summary": incident.forecast_summary or "",
        "general_advisory": incident.precaution_summary or "",
    })

    db_action = Action(
        incident_id=req.incident_id,
        action_type=req.action_type,
        strategy_name=req.strategy_name,
        parameters=req.parameters,
        status="planned",
        expected_effect=result,
    )
    db.add(db_action)
    db.commit()
    db.refresh(db_action)

    return {
        "action_id": db_action.id,
        "status": "planned",
        "agent_plan": result,
    }


@router.post("/simulate")
def simulate_action(req: SimulationRequest, db: Session = Depends(get_db)):
    """Run the SimulationAgent on a planned action."""
    action = db.query(Action).filter(Action.id == req.action_id).first()
    incident = db.query(Incident).filter(Incident.id == req.incident_id).first()
    if not action or not incident:
        raise HTTPException(status_code=404, detail="Action or Incident not found")

    from app.agents.agents import SimulationAgent, ImpactAssessmentAgent
    from app.agents.orchestrator import orchestrator

    input_data = {
        "crisis_type": incident.crisis_type,
        "severity": incident.severity,
        "location": incident.location_text,
        "primary_plan": action.expected_effect.get("primary_plan", []) if isinstance(action.expected_effect, dict) else [],
        "assignments": [],
        "predicted_duration_hours": incident.expected_duration_min / 60 if incident.expected_duration_min else 1,
        "affected_radius_km": incident.affected_radius_m / 1000 if incident.affected_radius_m else 1,
    }

    result = orchestrator.run_sequential(
        agents=[SimulationAgent(), ImpactAssessmentAgent()],
        initial_input=input_data,
        db=db,
        incident_id=incident.id,
    )

    db_sim = Simulation(
        incident_id=req.incident_id,
        action_id=req.action_id,
        before_state=result.get("before_state", {}),
        after_state=result.get("after_state", {}),
        side_effects={"unintended_consequences": result.get("unintended_consequences", [])},
        benefit_score=result.get("benefit_score", 0.0),
        risk_score=1.0 - result.get("improvement_percentage", 0.0) / 100,
    )
    db.add(db_sim)
    action.status = "simulated"
    db.commit()
    db.refresh(db_sim)

    return {
        "simulation_id": db_sim.id,
        "action_id": req.action_id,
        "agent_output": result,
    }


@router.post("/execute")
def execute_action(action_id: int, db: Session = Depends(get_db)):
    action = db.query(Action).filter(Action.id == action_id).first()
    if not action:
        raise HTTPException(status_code=404, detail="Action not found")

    from app.agents.agents import CommunicationAgent
    agent = CommunicationAgent()

    incident = db.query(Incident).filter(Incident.id == action.incident_id).first()
    result = agent.execute({
        "crisis_type": incident.crisis_type if incident else "unknown",
        "severity": incident.severity if incident else "unknown",
        "location": incident.location_text if incident else "unknown",
        "summary": incident.forecast_summary or "" if incident else "",
        "general_advisory": incident.precaution_summary or "" if incident else "",
        "primary_plan": action.expected_effect.get("primary_plan", []) if isinstance(action.expected_effect, dict) else [],
        "watch_level": "orange",
    })

    action.status = "executed"
    action.actual_effect = result
    db.commit()

    return {"action_id": action_id, "status": "executed", "communication": result}


@router.get("/{action_id}")
def get_action(action_id: int, db: Session = Depends(get_db)):
    action = db.query(Action).filter(Action.id == action_id).first()
    if not action:
        raise HTTPException(status_code=404, detail="Action not found")
    return {
        "id": action.id,
        "incident_id": action.incident_id,
        "action_type": action.action_type,
        "strategy_name": action.strategy_name,
        "parameters": action.parameters,
        "status": action.status,
        "expected_effect": action.expected_effect,
        "actual_effect": action.actual_effect,
        "created_at": action.created_at.isoformat() if action.created_at else None,
    }


@router.get("/simulation/{incident_id}")
def get_simulations(incident_id: int, db: Session = Depends(get_db)):
    sims = db.query(Simulation).filter(Simulation.incident_id == incident_id).all()
    return [
        {
            "id": s.id,
            "incident_id": s.incident_id,
            "action_id": s.action_id,
            "before_state": s.before_state,
            "after_state": s.after_state,
            "side_effects": s.side_effects,
            "benefit_score": s.benefit_score,
            "risk_score": s.risk_score,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        }
        for s in sims
    ]


from pydantic import BaseModel

class GenericSimulationRequest(BaseModel):
    strategy_type: str
    resource_allocation: float
    road_closures: int
    medical_deployment: float
    fuel_availability: float


@router.post("/simulate-generic")
def simulate_generic(req: GenericSimulationRequest, db: Session = Depends(get_db)):
    """Run simulation on standalone Strategy Simulator sliders dynamically using agents."""
    import json
    from app.agents.agents import SimulationAgent, ImpactAssessmentAgent
    from app.agents.orchestrator import orchestrator

    # Synthesize realistic action plans & resource assignments based on parameters
    primary_plan = [
        {
            "action_type": "dispatch" if req.strategy_type != "conservative" else "monitor",
            "strategy_name": req.strategy_type.capitalize(),
            "description": f"Deploy resources with {req.resource_allocation}% allocation and {req.road_closures} road closures.",
            "priority": "high" if req.strategy_type == "aggressive" else "medium",
            "estimated_impact": "Accelerate hazard clearing and restore service routes",
            "trade_offs": "High resource utilization" if req.resource_allocation > 70 else "Adequate reserve margins"
        }
    ]

    assignments = [
        {
            "resource_type": "police",
            "quantity": int(req.road_closures),
            "deploy_from": "HQ Depot",
            "deploy_to": "Tactical Intersections",
            "estimated_arrival_min": 15,
            "conflict_note": "High demand" if req.road_closures > 10 else "None"
        },
        {
            "resource_type": "medical_team",
            "quantity": max(1, int(req.medical_deployment / 10)),
            "deploy_from": "District Hospital",
            "deploy_to": "Response Zone",
            "estimated_arrival_min": 20,
            "conflict_note": "None"
        }
    ]

    input_data = {
        "crisis_type": "flood",
        "severity": "critical" if req.strategy_type == "aggressive" else "high" if req.strategy_type == "balanced" else "medium",
        "location": "Sector G-10 Islamabad",
        "primary_plan": primary_plan,
        "assignments": assignments,
        "predicted_duration_hours": float(max(2.0, 24.0 * (1.0 - req.resource_allocation/150.0))),
        "affected_radius_km": float(max(0.5, 4.0 * (1.0 - req.resource_allocation/200.0))),
        "total_resources_used": int(req.resource_allocation / 10)
    }

    # Execute dynamic agent simulation
    result = orchestrator.run_sequential(
        agents=[SimulationAgent(), ImpactAssessmentAgent()],
        initial_input=input_data,
        db=db,
    )

    # Standardize result structure for the simulator UI
    improvement = result.get("improvement_percentage", 50.0)
    benefit_score = result.get("benefit_score", 0.6)
    
    # Deriving UI result parameters
    congestion_reduction = float(improvement)
    casualty_estimate = int(max(0, 10 - int(req.medical_deployment / 10)))
    recovery_time = float(result.get("predicted_duration_hours") or input_data["predicted_duration_hours"])
    resource_usage = float(req.resource_allocation)
    
    # Formatting AI text recommendations nicely
    rec = result.get("recommendation", "proceed")
    ai_rec = result.get("before_after_comparison", "")
    if not ai_rec:
        ai_rec = f"{req.strategy_type.capitalize()} strategy simulation completed. Predicted improvement: {improvement}%. Recommendation: {rec}."

    return {
        "strategy": req.strategy_type,
        "congestionReduction": congestion_reduction,
        "casualtyEstimate": casualty_estimate,
        "recoveryTimeHours": recovery_time,
        "resourceUsage": resource_usage,
        "aiRecommendation": ai_rec
    }


class StrategySimulationRequest(BaseModel):
    incident_id: int

@router.post("/simulate/strategies")
def simulate_strategies(req: StrategySimulationRequest, db: Session = Depends(get_db)):
    """Run simulation on an incident with 3 different response strategies in parallel."""
    incident = db.query(Incident).filter(Incident.id == req.incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    from app.agents.agents import SimulationAgent
    from app.agents.orchestrator import orchestrator

    base_input = {
        "crisis_type": incident.crisis_type,
        "severity": incident.severity,
        "location": incident.location_text,
        "predicted_duration_hours": incident.expected_duration_min / 60 if incident.expected_duration_min else 12.0,
        "affected_radius_km": incident.affected_radius_m / 1000 if incident.affected_radius_m else 2.5,
    }

    # Prepare variations
    aggressive_input = dict(base_input)
    aggressive_input["primary_plan"] = [{"action_type": "evacuate", "strategy_name": "Aggressive", "description": "Mandatory immediate evacuation and mass resource deployment."}]
    aggressive_input["assignments"] = [{"resource_type": "police", "quantity": 20}, {"resource_type": "ambulance", "quantity": 10}]
    
    balanced_input = dict(base_input)
    balanced_input["primary_plan"] = [{"action_type": "reroute", "strategy_name": "Balanced", "description": "Reroute traffic and deploy targeted rescue."}]
    balanced_input["assignments"] = [{"resource_type": "police", "quantity": 10}, {"resource_type": "ambulance", "quantity": 5}]
    
    conservative_input = dict(base_input)
    conservative_input["primary_plan"] = [{"action_type": "alert", "strategy_name": "Conservative", "description": "Issue warnings and monitor situation before committing resources."}]
    conservative_input["assignments"] = [{"resource_type": "police", "quantity": 2}, {"resource_type": "ambulance", "quantity": 1}]

    import concurrent.futures
    
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        f_agg = executor.submit(orchestrator.run_sequential, [SimulationAgent()], aggressive_input)
        f_bal = executor.submit(orchestrator.run_sequential, [SimulationAgent()], balanced_input)
        f_con = executor.submit(orchestrator.run_sequential, [SimulationAgent()], conservative_input)
        
        results["aggressive"] = f_agg.result()
        results["balanced"] = f_bal.result()
        results["conservative"] = f_con.result()

    return {
        "incident_id": req.incident_id,
        "strategies": {
            "aggressive": results["aggressive"],
            "balanced": results["balanced"],
            "conservative": results["conservative"]
        }
    }

