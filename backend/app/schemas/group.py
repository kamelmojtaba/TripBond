"""
Group Schemas

Pydantic models for request/response validation in group endpoints.
"""
from pydantic import BaseModel
from typing import List, Optional, Dict, Any


class GroupMember(BaseModel):
    user_id: str
    weight: Optional[float] = 1.0  # Weight for weighted aggregation


class AggregationStrategy(BaseModel):
    method: str  # 'least_misery', 'average', 'majority_rule', 'weighted_average', 'most_pleasure'
    threshold: Optional[float] = None  # For majority rule


class GroupAggregationRequest(BaseModel):
    members: List[GroupMember]
    strategy: AggregationStrategy


class GAOptimizationRequest(BaseModel):
    trip_id: str
    members: List[str]  # List of user_ids
    population_size: Optional[int] = 50
    generations: Optional[int] = 100
    mutation_rate: Optional[float] = 0.1
    crossover_rate: Optional[float] = 0.7
    constraints: Optional[Dict[str, Any]] = None


class GroupPreferenceModel(BaseModel):
    trip_id: str
    group_size: int
    aggregated_preferences: Dict[str, Any]
    strategy_used: str
    individual_preferences: List[Dict[str, Any]]
    consensus_score: Optional[float] = None  # How well the group agrees
    diversity_score: Optional[float] = None  # How diverse the group is


class OptimizationResult(BaseModel):
    trip_id: str
    recommended_activities: List[Dict[str, Any]]
    recommended_destinations: List[Dict[str, Any]]
    fitness_score: float
    generation: int
    strategy: str
    explanation: str
