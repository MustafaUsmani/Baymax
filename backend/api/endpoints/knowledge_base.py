"""CIRO+ Knowledge Base Endpoints — full query support for all KB categories."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.models.db_models import KnowledgeBaseEntry, AppInteractionRule

router = APIRouter()


@router.get("/playbooks")
def get_playbooks(crisis_type: Optional[str] = None, db: Session = Depends(get_db)):
    """Return crisis playbooks, optionally filtered by crisis type tag."""
    q = db.query(KnowledgeBaseEntry).filter(KnowledgeBaseEntry.category == "playbook")
    if crisis_type:
        q = q.filter(KnowledgeBaseEntry.tags.ilike(f"%{crisis_type}%"))
    return [_kb_to_dict(e) for e in q.all()]


@router.get("/triggers")
def get_triggers(tag: Optional[str] = None, db: Session = Depends(get_db)):
    """Return trigger rules, optionally filtered by tag."""
    q = db.query(KnowledgeBaseEntry).filter(KnowledgeBaseEntry.category == "trigger")
    if tag:
        q = q.filter(KnowledgeBaseEntry.tags.ilike(f"%{tag}%"))
    return [_kb_to_dict(e) for e in q.all()]


@router.get("/source-policies")
def get_source_policies(db: Session = Depends(get_db)):
    """Return source reliability and verification policies."""
    return [_kb_to_dict(e) for e in
            db.query(KnowledgeBaseEntry).filter(KnowledgeBaseEntry.category == "policy").all()]


@router.get("/schemas")
def get_output_schemas(db: Session = Depends(get_db)):
    """Return output JSON schema definitions for the Flutter app / dashboard."""
    return [_kb_to_dict(e) for e in
            db.query(KnowledgeBaseEntry).filter(KnowledgeBaseEntry.category == "schema").all()]


@router.get("/app-interactions")
def get_app_interactions(db: Session = Depends(get_db)):
    """Return user-intent → backend-action mapping rules."""
    rules = db.query(AppInteractionRule).all()
    return [
        {
            "id": r.id,
            "user_intent": r.user_intent,
            "backend_endpoint": r.backend_endpoint,
            "agent_chain": r.agent_chain,
            "response_schema": r.response_schema,
            "notes": r.notes,
        }
        for r in rules
    ]


@router.get("/search")
def search_kb(q: str = Query(..., min_length=2), db: Session = Depends(get_db)):
    """Full-text search across all KB entries."""
    results = (
        db.query(KnowledgeBaseEntry)
        .filter(
            KnowledgeBaseEntry.title.ilike(f"%{q}%")
            | KnowledgeBaseEntry.content.ilike(f"%{q}%")
            | KnowledgeBaseEntry.tags.ilike(f"%{q}%")
        )
        .all()
    )
    return [_kb_to_dict(e) for e in results]


def _kb_to_dict(e: KnowledgeBaseEntry) -> dict:
    return {
        "id": e.id,
        "category": e.category,
        "title": e.title,
        "content": e.content,
        "tags": e.tags,
        "version": e.version,
        "updated_at": e.updated_at.isoformat() if e.updated_at else None,
    }
