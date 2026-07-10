from fastapi import APIRouter, Depends, HTTPException, status
from ..schemas.group import (
    GroupAggregationRequest,
    GAOptimizationRequest,
    GroupPreferenceModel,
    OptimizationResult,
)
from ..services import group_service
from ..services.trip_access import check_trip_access
from ..auth import get_current_user_context

router = APIRouter()


@router.post("/{trip_id}/aggregate", response_model=GroupPreferenceModel)
async def aggregate_group_preferences(
    trip_id: str,
    request: GroupAggregationRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Aggregate preferences from group members. Members only."""
    user_id, token = user_context
    await check_trip_access(trip_id, user_id, token=token, required_role="member")
    try:
        return group_service.aggregate_group_preferences(trip_id, request)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to aggregate group preferences: {str(e)}",
        )


@router.post("/{trip_id}/optimize", response_model=OptimizationResult)
async def optimize_group_recommendations(
    trip_id: str,
    request: GAOptimizationRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Run GA on group preferences. Creator only."""
    user_id, token = user_context
    await check_trip_access(trip_id, user_id, token=token, required_role="creator")
    try:
        return group_service.optimize_group_recommendations(trip_id, request)
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to optimize recommendations: {str(e)}",
        )
