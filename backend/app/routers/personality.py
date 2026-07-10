from fastapi import APIRouter, HTTPException, status, Depends
from ..auth import get_current_user_context
from ..schemas.personality import (
    QuizSubmission,
    PersonalityScores,
    PersonalityUpdateRequest,
)
from ..services import personality_service

router = APIRouter()


@router.get("/questions")
async def get_quiz_questions():
    """Get all personality quiz questions."""
    return personality_service.get_quiz_questions()


@router.post("/submit", response_model=PersonalityScores)
async def submit_quiz(
    submission: QuizSubmission,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """
    Submit quiz answers and calculate + persist Big Five personality scores.
    Also saves individual answers to the personality_answers table.
    """
    user_id, _token = user_context
    if submission.user_id and submission.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot submit quiz for another user",
        )
    try:
        return personality_service.submit_quiz_answers(user_id, submission.answers)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to submit quiz: {str(e)}",
        )


@router.put("/{user_id}", response_model=PersonalityScores)
async def update_personality_scores(user_id: str, scores: PersonalityUpdateRequest):
    """Update personality scores for a user (partial update supported)."""
    try:
        update_data = {k: v for k, v in scores.model_dump().items() if v is not None}
        return personality_service.update_personality_scores(user_id, update_data)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update personality scores: {str(e)}",
        )


@router.get("/scores/{user_id}", response_model=PersonalityScores)
async def get_personality_scores(user_id: str):
    """Get personality scores for a user."""
    try:
        return personality_service.get_personality_scores(user_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get personality scores: {str(e)}",
        )
