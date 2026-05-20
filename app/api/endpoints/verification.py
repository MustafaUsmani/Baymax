"""CIRO+ Verification Endpoints — real DB + agent pipeline."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.db_models import HumanReport
from app.workflows.incident_response_workflow import run_verification_only

router = APIRouter()


@router.post("/request")
def request_verification(report_id: int, db: Session = Depends(get_db)):
    report = db.query(HumanReport).filter(HumanReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    result = run_verification_only(
        {
            "raw_text": report.text,
            "source": "user_report",
            "is_human_report": True,
        },
        db=db,
    )

    report.report_status = result.get("verification_status", "unverified")
    report.verified_by_agent = result.get("verification_status") in ("verified", "partially_verified")
    report.verification_score = result.get("credibility_score", 0.0)
    db.commit()

    return {
        "report_id": report_id,
        "verification_status": report.report_status,
        "credibility_score": report.verification_score,
        "pipeline_traces": result.get("pipeline_traces", []),
    }


@router.post("/confirm")
def confirm_verification(report_id: int, db: Session = Depends(get_db)):
    report = db.query(HumanReport).filter(HumanReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    report.report_status = "verified"
    report.verified_by_agent = True
    report.verification_score = 1.0
    db.commit()

    return {"report_id": report_id, "status": "manually_confirmed"}


@router.get("/reports/{report_id}")
def get_report(report_id: int, db: Session = Depends(get_db)):
    report = db.query(HumanReport).filter(HumanReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return {
        "id": report.id,
        "user_id": report.user_id,
        "incident_id": report.incident_id,
        "text": report.text,
        "attachment_url": report.attachment_url,
        "report_status": report.report_status,
        "verified_by_agent": report.verified_by_agent,
        "verification_score": report.verification_score,
        "timestamp": report.timestamp.isoformat() if report.timestamp else None,
    }


@router.get("/reports/{report_id}/status")
def get_report_status(report_id: int, db: Session = Depends(get_db)):
    report = db.query(HumanReport).filter(HumanReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return {
        "report_id": report_id,
        "verification_status": report.report_status,
        "verified_by_agent": report.verified_by_agent,
        "verification_score": report.verification_score,
    }
