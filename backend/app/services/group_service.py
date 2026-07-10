"""
Group Service

Handles group preference aggregation, consensus scoring,
and Genetic Algorithm (GA) optimisation for group trips.
Routers delegate all group business logic to this service.
"""
from typing import List, Optional, Dict, Any
from collections import Counter
from itertools import combinations
from ..database import SupabaseDB
import logging

logger = logging.getLogger(__name__)


# ==================== Aggregation Strategies ====================

def apply_aggregation_strategy(
    individual_prefs: List[Dict],
    method: str,
    threshold: Optional[float] = None
) -> Dict[str, Any]:
    """Dispatch to the correct aggregation strategy."""
    dispatch = {
        "least_misery": lambda: least_misery_aggregation(individual_prefs),
        "average": lambda: average_aggregation(individual_prefs),
        "majority_rule": lambda: majority_rule_aggregation(individual_prefs, threshold or 0.5),
        "weighted_average": lambda: weighted_average_aggregation(individual_prefs),
        "most_pleasure": lambda: most_pleasure_aggregation(individual_prefs),
    }
    return dispatch.get(method, lambda: average_aggregation(individual_prefs))()


def least_misery_aggregation(prefs: List[Dict]) -> Dict[str, Any]:
    """Select the most conservative option for each preference (minimise dissatisfaction)."""
    result: Dict[str, Any] = {}

    all_activities = [set(p.get("trip_preferences", {}).get("activity_tags", [])) for p in prefs]
    non_empty = [s for s in all_activities if s]
    if non_empty:
        result["activity_tags"] = list(set.intersection(*non_empty))

    paces = {"slow": 1, "moderate": 2, "fast": 3}
    pace_values = [
        p.get("trip_preferences", {}).get("pace")
        for p in prefs
        if p.get("trip_preferences", {}).get("pace")
    ]
    if pace_values:
        result["pace"] = min(pace_values, key=lambda x: paces.get(x, 2))

    budgets = {"low": 1, "medium": 2, "high": 3}
    budget_values = [
        p.get("general_preferences", {}).get("budget_level")
        for p in prefs
        if p.get("general_preferences", {}).get("budget_level")
    ]
    if budget_values:
        result["budget_level"] = min(budget_values, key=lambda x: budgets.get(x, 2))

    return result


def average_aggregation(prefs: List[Dict]) -> Dict[str, Any]:
    """Keep activities mentioned by at least 50% of the group; average Big Five traits."""
    result: Dict[str, Any] = {}

    all_activities: List[str] = []
    for p in prefs:
        all_activities.extend(p.get("trip_preferences", {}).get("activity_tags", []))

    if all_activities:
        activity_counts = Counter(all_activities)
        threshold = len(prefs) / 2
        result["activity_tags"] = [a for a, c in activity_counts.items() if c >= threshold]

    for trait in ("openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"):
        values = [
            p.get("personality", {}).get(trait)
            for p in prefs
            if p.get("personality", {}).get(trait) is not None
        ]
        if values:
            result[trait] = sum(values) / len(values)

    return result


def majority_rule_aggregation(prefs: List[Dict], threshold: float) -> Dict[str, Any]:
    """Include only preferences chosen by a majority of the group."""
    result: Dict[str, Any] = {}
    group_size = len(prefs)

    all_activities: List[str] = []
    for p in prefs:
        all_activities.extend(p.get("trip_preferences", {}).get("activity_tags", []))

    if all_activities:
        activity_counts = Counter(all_activities)
        result["activity_tags"] = [
            a for a, c in activity_counts.items()
            if c / group_size >= threshold
        ]

    travel_styles = [
        p.get("general_preferences", {}).get("travel_style")
        for p in prefs
        if p.get("general_preferences", {}).get("travel_style")
    ]
    if travel_styles:
        result["travel_style"] = Counter(travel_styles).most_common(1)[0][0]

    return result


def weighted_average_aggregation(prefs: List[Dict]) -> Dict[str, Any]:
    """Weight each member's preferences by their assigned weight."""
    result: Dict[str, Any] = {}

    for trait in ("openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"):
        weighted_sum = 0.0
        total_weight = 0.0
        for p in prefs:
            value = p.get("personality", {}).get(trait)
            if value is not None:
                weight = p.get("weight", 1.0)
                weighted_sum += value * weight
                total_weight += weight
        if total_weight > 0:
            result[trait] = weighted_sum / total_weight

    return result


def most_pleasure_aggregation(prefs: List[Dict]) -> Dict[str, Any]:
    """Maximise the maximum satisfaction (opposite of least misery)."""
    result: Dict[str, Any] = {}

    all_activities: set = set()
    for p in prefs:
        all_activities.update(p.get("trip_preferences", {}).get("activity_tags", []))
    result["activity_tags"] = list(all_activities)

    paces = {"slow": 1, "moderate": 2, "fast": 3}
    pace_values = [
        p.get("trip_preferences", {}).get("pace")
        for p in prefs
        if p.get("trip_preferences", {}).get("pace")
    ]
    if pace_values:
        result["pace"] = max(pace_values, key=lambda x: paces.get(x, 2))

    budgets = {"low": 1, "medium": 2, "high": 3}
    budget_values = [
        p.get("general_preferences", {}).get("budget_level")
        for p in prefs
        if p.get("general_preferences", {}).get("budget_level")
    ]
    if budget_values:
        result["budget_level"] = max(budget_values, key=lambda x: budgets.get(x, 3))

    return result


# ==================== Scoring ====================

def calculate_consensus_score(prefs: List[Dict]) -> float:
    """Calculate how much the group agrees (0–1 scale) based on Jaccard similarity."""
    if len(prefs) < 2:
        return 1.0

    activity_sets = [
        set(p.get("trip_preferences", {}).get("activity_tags", []))
        for p in prefs
    ]
    activity_sets = [s for s in activity_sets if s]

    if len(activity_sets) < 2:
        return 0.5

    similarities = []
    for s1, s2 in combinations(activity_sets, 2):
        intersection = len(s1 & s2)
        union = len(s1 | s2)
        if union > 0:
            similarities.append(intersection / union)

    return sum(similarities) / len(similarities) if similarities else 0.5


def calculate_diversity_score(prefs: List[Dict]) -> float:
    """Inverse of consensus — higher diversity means less agreement."""
    return 1.0 - calculate_consensus_score(prefs)


# ==================== Database helpers ====================

def fetch_member_preferences(trip_id: str, member_user_ids: List[str]) -> List[Dict]:
    """
    Fetch trip + general + personality preferences for each member.
    Returns a list of dicts, one per member.
    """
    db = SupabaseDB()
    individual_prefs = []

    for user_id in member_user_ids:
        trip_prefs = db.client.table("trip_preferences").select("*").eq(
            "trip_id", trip_id
        ).eq("user_id", user_id).execute()

        user_prefs = db.client.table("profiles").select(
            "budget_level, travel_style, dietary_preferences, preferred_accommodation, preferred_transport"
        ).eq("id", user_id).execute()

        personality = db.client.table("profiles").select(
            "openness, conscientiousness, extraversion, agreeableness, neuroticism"
        ).eq("id", user_id).execute()

        individual_prefs.append({
            "user_id": user_id,
            "weight": 1.0,
            "trip_preferences": trip_prefs.data[0] if trip_prefs.data else {},
            "general_preferences": user_prefs.data[0] if user_prefs.data else {},
            "personality": personality.data[0] if personality.data else {},
        })

    return individual_prefs


def save_group_model(trip_id: str, aggregated: Dict, strategy: str,
                     group_size: int, consensus: float, diversity: float) -> None:
    """Persist the aggregated group model to the database."""
    db = SupabaseDB()
    db.client.table("group_models").upsert({
        "trip_id": trip_id,
        "aggregated_preferences": aggregated,
        "strategy": strategy,
        "group_size": group_size,
        "consensus_score": consensus,
        "diversity_score": diversity,
    }).execute()


def get_group_model(trip_id: str) -> Optional[Dict]:
    """Retrieve the stored group model for a trip."""
    db = SupabaseDB()
    response = db.client.table("group_models").select("*").eq("trip_id", trip_id).execute()
    return response.data[0] if response.data else None


def get_individual_preferences_for_trip(trip_id: str) -> List[Dict]:
    """Get individual trip preferences for all members of a trip."""
    db = SupabaseDB()
    members_response = db.client.table("trip_participants").select("user_id").eq(
        "trip_id", trip_id
    ).execute()

    individual_prefs = []
    if members_response.data:
        for member in members_response.data:
            prefs = db.client.table("trip_preferences").select("*").eq(
                "trip_id", trip_id
            ).eq("user_id", member["user_id"]).execute()
            if prefs.data:
                individual_prefs.append(prefs.data[0])

    return individual_prefs


def save_optimization_result(trip_id: str, result: Dict, request_params: Dict) -> None:
    """Persist GA optimisation result to the database."""
    db = SupabaseDB()
    db.client.table("optimization_results").insert({
        "trip_id": trip_id,
        "recommendations": result["recommendations"],
        "fitness_score": result["fitness_score"],
        "generation": result["generation"],
        "parameters": request_params,
    }).execute()


def get_optimization_history(trip_id: str) -> List[Dict]:
    """Get the list of past optimisation runs for a trip."""
    db = SupabaseDB()
    response = db.client.table("optimization_results").select("*").eq(
        "trip_id", trip_id
    ).order("created_at", desc=True).execute()
    return response.data if response.data else []


# ==================== Public API wrappers ====================

def aggregate_group_preferences(trip_id: str, request) -> Any:
    """
    High-level wrapper: fetch member preferences, aggregate, save, and return
    a GroupPreferenceModel. Called by the router for POST /{trip_id}/aggregate.
    """
    from ..schemas.group import GroupPreferenceModel

    member_user_ids = [m.user_id for m in request.members]
    individual_prefs = fetch_member_preferences(trip_id, member_user_ids)

    # Apply per-member weights from request
    for i, member in enumerate(request.members):
        if i < len(individual_prefs):
            individual_prefs[i]["weight"] = member.weight

    method = request.strategy.method
    threshold = request.strategy.threshold
    aggregated = apply_aggregation_strategy(individual_prefs, method, threshold)
    consensus = calculate_consensus_score(individual_prefs)
    diversity = calculate_diversity_score(individual_prefs)

    save_group_model(trip_id, aggregated, method, len(individual_prefs), consensus, diversity)

    return GroupPreferenceModel(
        trip_id=trip_id,
        group_size=len(individual_prefs),
        aggregated_preferences=aggregated,
        strategy_used=method,
        individual_preferences=individual_prefs,
        consensus_score=consensus,
        diversity_score=diversity,
    )


def optimize_group_recommendations(trip_id: str, request) -> Any:
    """
    High-level wrapper: retrieve the group model then delegate itinerary
    optimization to itinerary_service (single owner of all GA logic).
    Called by the router for POST /{trip_id}/optimize.
    """
    from fastapi import HTTPException, status
    from ..schemas.group import OptimizationResult
    from .itinerary_service import generate_itinerary as _generate_itinerary

    group_model = get_group_model(trip_id)
    if not group_model:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No group model found for this trip — run aggregation first.",
        )

    trip_data = {
        "id": trip_id,
        "destination": group_model.get("aggregated_preferences", {}).get("destination", ""),
        "trip_type": "group",
    }
    constraints = request.constraints or {}
    itinerary_data, strategy = _generate_itinerary(
        trip_data,
        group_preferences=group_model["aggregated_preferences"],
        use_ga=True,
        max_budget=constraints.get("max_budget"),
        pace=constraints.get("pace", "moderate"),
    )

    all_activities: List[Dict] = []
    all_destinations: List[Dict] = []
    for day in itinerary_data.get("days", []):
        for act in day.get("activities", []):
            all_activities.append({
                "name": act.get("name", ""),
                "score": 0.85,
                "match_reason": "Group preference match",
            })
        dest = day.get("destination")
        if dest:
            all_destinations.append({"name": dest, "score": 0.85, "match_reason": "Group consensus"})

    result_record = {
        "trip_id": trip_id,
        "recommendations": {"activities": [a["name"] for a in all_activities[:5]]},
        "fitness_score": itinerary_data.get("fitness_score", 0.85),
        "generation": request.generations or 100,
    }
    save_optimization_result(trip_id, result_record, request.model_dump())

    return OptimizationResult(
        trip_id=trip_id,
        recommended_activities=all_activities[:10],
        recommended_destinations=all_destinations[:5],
        fitness_score=itinerary_data.get("fitness_score", 0.85),
        generation=request.generations or 100,
        strategy=strategy,
        explanation=itinerary_data.get(
            "explanation",
            f"Optimized using {strategy} strategy for {len(request.members)} members.",
        ),
    )
