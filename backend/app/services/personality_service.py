"""
Personality Service

Handles Big Five personality quiz logic, score calculation, and database operations.
Routers delegate all personality-related business logic to this service.
"""
from fastapi import HTTPException, status
from typing import List
from ..database import SupabaseDB
from ..schemas.personality import QuizAnswer, PersonalityScores
import logging

logger = logging.getLogger(__name__)


def _admin_db():
    """Service-role client so profile updates are not blocked by RLS."""
    return SupabaseDB(admin=True).client


# Big 5 Questions mapping - each question maps to a trait and direction
# Positive questions: higher score means higher trait value
# Negative questions: higher score means lower trait value (reverse scored)
QUIZ_QUESTIONS = {
    1: {"trait": "openness", "direction": "positive",
        "text": "I enjoy visiting new places and experiencing different cultures when I travel."},
    2: {"trait": "conscientiousness", "direction": "positive",
        "text": "I prefer trips that include museums, heritage sites, or other local experiences."},
    3: {"trait": "openness", "direction": "positive",
        "text": "I like my trips to be well organized with clear schedules and plans."},
    4: {"trait": "conscientiousness", "direction": "positive",
        "text": "I prefer following a planned itinerary rather than deciding activities spontaneously."},
    5: {"trait": "extraversion", "direction": "positive",
        "text": "I enjoy social activities such as events, nightlife, or group entertainment while traveling."},
    6: {"trait": "extraversion", "direction": "positive",
        "text": "I like traveling with others and participating in lively or group based activities."},
    7: {"trait": "agreeableness", "direction": "positive",
        "text": "I prefer travel activities that help everyone in the group feel comfortable and relaxed."},
    8: {"trait": "agreeableness", "direction": "positive",
        "text": "I enjoy calm experiences such as nature, food tasting, or wellness activities."},
    9: {"trait": "neuroticism", "direction": "negative",
        "text": "I feel more comfortable visiting places that are familiar, safe, and predictable."},
    10: {"trait": "neuroticism", "direction": "negative",
         "text": "I prefer avoiding risky or stressful travel situations."}
}


def calculate_personality_scores(answers: List[QuizAnswer]) -> PersonalityScores:
    """
    Calculate Big 5 personality scores from quiz answers.
    Scores range from 0.0 (low) to 1.0 (high).
    """
    trait_scores = {
        "openness": [],
        "conscientiousness": [],
        "extraversion": [],
        "agreeableness": [],
        "neuroticism": []
    }

    answer_map = {
        "agree": 1.0,
        "neutral": 0.5,
        "disagree": 0.0
    }

    for answer in answers:
        question = QUIZ_QUESTIONS.get(answer.question_id)
        if not question:
            continue

        trait = question["trait"]
        direction = question["direction"]
        score = answer_map.get(answer.answer.lower(), 0.5)

        if direction == "negative":
            score = 1.0 - score

        trait_scores[trait].append(score)

    final_scores = {}
    for trait, scores in trait_scores.items():
        final_scores[trait] = sum(scores) / len(scores) if scores else 0.5

    return PersonalityScores(**final_scores)


def get_quiz_questions() -> dict:
    """Return the quiz questions list."""
    questions = []
    for q_id, q_data in sorted(QUIZ_QUESTIONS.items()):
        questions.append({"id": q_id, "text": q_data["text"]})
    return {"questions": questions, "total": len(questions)}


def submit_quiz_answers(user_id: str, answers: List[QuizAnswer]) -> PersonalityScores:
    """
    Calculate scores, persist them to profiles, and save individual answers.
    """
    if not answers:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No answers provided"
        )

    scores = calculate_personality_scores(answers)

    client = _admin_db()
    update_data = {
        "openness": scores.openness,
        "conscientiousness": scores.conscientiousness,
        "extraversion": scores.extraversion,
        "agreeableness": scores.agreeableness,
        "neuroticism": scores.neuroticism
    }

    response = client.table("profiles").update(update_data).eq("id", user_id).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found"
        )

    # Persist individual answers
    try:
        client.table("personality_answers").delete().eq("user_id", user_id).execute()

        answers_to_insert = []
        for answer in answers:
            question = QUIZ_QUESTIONS.get(answer.question_id)
            if question:
                answer_value = (
                    2 if answer.answer.lower() == "agree"
                    else 1 if answer.answer.lower() == "neutral"
                    else 0
                )
                answers_to_insert.append({
                    "user_id": user_id,
                    "question_id": answer.question_id,
                    "answer_value": answer_value,
                })

        if answers_to_insert:
            client.table("personality_answers").insert(answers_to_insert).execute()

    except Exception as e:
        logger.warning(f"Failed to save personality answers: {e}")

    return scores


def update_personality_scores(user_id: str, updates: dict) -> PersonalityScores:
    """Partially update personality scores for a user."""
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No personality scores provided for update"
        )

    client = _admin_db()
    response = client.table("profiles").update(updates).eq("id", user_id).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found"
        )

    profile = response.data[0]
    return PersonalityScores(
        openness=profile.get("openness", 0.5),
        conscientiousness=profile.get("conscientiousness", 0.5),
        extraversion=profile.get("extraversion", 0.5),
        agreeableness=profile.get("agreeableness", 0.5),
        neuroticism=profile.get("neuroticism", 0.5)
    )


def get_personality_scores(user_id: str) -> PersonalityScores:
    """Retrieve personality scores for a user."""
    client = _admin_db()
    response = client.table("profiles").select(
        "openness, conscientiousness, extraversion, agreeableness, neuroticism"
    ).eq("id", user_id).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found"
        )

    profile = response.data[0]
    return PersonalityScores(
        openness=profile.get("openness", 0.5),
        conscientiousness=profile.get("conscientiousness", 0.5),
        extraversion=profile.get("extraversion", 0.5),
        agreeableness=profile.get("agreeableness", 0.5),
        neuroticism=profile.get("neuroticism", 0.5)
    )
