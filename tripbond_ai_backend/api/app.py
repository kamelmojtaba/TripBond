"""
TripBond Flask API Server
==========================
Production-ready REST API for TripBond AI recommendation system.

Endpoints:
- GET  /health                  - Health check
- POST /recommend/group         - Group POI recommendations
- POST /itinerary/group         - Group itinerary generation (GA or Greedy)

Author: TripBond AI Team
Date: 2026-02-21
"""

from flask import Flask, request, jsonify
from pathlib import Path
import pandas as pd
import numpy as np
import sys
import warnings
warnings.filterwarnings('ignore')

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Import existing classes
from api.group_recommendations import TripBondGroupRecommender
from api.build_itinerary import GreedyItineraryBuilder
from api.build_itinerary_ga import GeneticItineraryOptimizer


# Initialize Flask app
app = Flask(__name__)
app.config['JSON_SORT_KEYS'] = False


# ============================================================================
# Helper Functions
# ============================================================================

def validate_user_ids(user_ids):
    """Validate user_ids input."""
    if not user_ids:
        return False, "user_ids cannot be empty"
    if not isinstance(user_ids, list):
        return False, "user_ids must be a list"
    if len(user_ids) < 1:
        return False, "At least one user_id is required"
    return True, None


def validate_method(method):
    """Validate itinerary method."""
    valid_methods = ['ga', 'greedy']
    if method not in valid_methods:
        return False, f"method must be one of {valid_methods}"
    return True, None


def run_group_recommendations(user_ids, top_k=15):
    """
    Run group recommendation engine.
    
    Args:
        user_ids: List of user IDs
        top_k: Number of top POIs to return
        
    Returns:
        DataFrame with group recommendations
    """
    # Initialize recommender with specific user IDs
    recommender = TripBondGroupRecommender(user_ids=user_ids)
    
    # Run pipeline (returns recommendations DataFrame)
    recommendations = recommender.run(top_n=top_k)
    
    return recommendations


def run_greedy_itinerary(num_stops=5):
    """
    Run greedy itinerary builder.
    
    Args:
        num_stops: Number of stops in itinerary
        
    Returns:
        DataFrame with itinerary
    """
    builder = GreedyItineraryBuilder(top_n_pois=num_stops)
    
    builder.load_data()
    builder.detect_columns()
    builder.select_top_pois()
    builder.build_greedy_itinerary()
    
    return builder.itinerary


def run_ga_itinerary(num_stops=5):
    """
    Run GA itinerary optimizer.
    
    Args:
        num_stops: Number of stops in itinerary
        
    Returns:
        tuple: (DataFrame with itinerary, best_fitness)
    """
    optimizer = GeneticItineraryOptimizer(
        candidate_pool_size=min(10, num_stops * 2),
        itinerary_size=num_stops,
        population_size=40,
        generations=50,
        tournament_size=3,
        crossover_rate=0.8,
        mutation_rate=0.2,
        random_seed=42
    )
    
    optimizer.load_data()
    optimizer.detect_columns()
    optimizer.select_candidate_pool()
    optimizer.initialize_population()
    optimizer.evolve()
    
    itinerary_df, total_cost = optimizer.build_itinerary_from_chromosome(
        optimizer.best_chromosome
    )
    
    return itinerary_df, optimizer.best_fitness


def save_temp_group_recommendations(group_recs_df):
    """
    Save group recommendations to temporary file for itinerary builders.
    
    Args:
        group_recs_df: DataFrame with group recommendations
    """
    project_root = Path(__file__).parent.parent
    data_dir = project_root / "data"
    output_file = data_dir / "top_pois_for_group.csv"
    
    data_dir.mkdir(parents=True, exist_ok=True)
    group_recs_df.to_csv(output_file, index=False)


def dataframe_to_json_safe(df):
    """
    Convert DataFrame to JSON-safe dict list.
    
    Args:
        df: pandas DataFrame
        
    Returns:
        list: List of dictionaries
    """
    # Replace NaN with None for JSON serialization
    df_clean = df.replace({np.nan: None})
    return df_clean.to_dict(orient='records')


# ============================================================================
# API Endpoints
# ============================================================================

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({"status": "ok"}), 200


@app.route('/recommend/group', methods=['POST'])
def recommend_group():
    """
    Group recommendation endpoint.
    
    Request body:
    {
        "user_ids": ["USER_000001", "USER_000002", "USER_000003"],
        "top_k": 15
    }
    
    Response:
    {
        "success": true,
        "num_users": 3,
        "num_pois": 15,
        "recommendations": [
            {
                "poi_id": "POI_017",
                "final_group_score": 0.6893,
                "avg_score": 0.7234,
                "min_score": 0.6234,
                "fairness_score": 0.9123,
                "poi_category": "landmark",
                ...
            },
            ...
        ]
    }
    """
    try:
        # Parse request
        data = request.get_json()
        
        if not data:
            return jsonify({
                "success": False,
                "error": "No JSON data provided"
            }), 400
        
        user_ids = data.get('user_ids', [])
        top_k = data.get('top_k', 15)
        
        # Validate inputs
        valid, error_msg = validate_user_ids(user_ids)
        if not valid:
            return jsonify({
                "success": False,
                "error": error_msg
            }), 400
        
        if not isinstance(top_k, int) or top_k < 1:
            return jsonify({
                "success": False,
                "error": "top_k must be a positive integer"
            }), 400
        
        # Run group recommendations
        group_recs = run_group_recommendations(user_ids, top_k)
        
        # Convert to JSON-safe format
        recommendations = dataframe_to_json_safe(group_recs)
        
        # Save for potential itinerary use
        save_temp_group_recommendations(group_recs)
        
        return jsonify({
            "success": True,
            "num_users": len(user_ids),
            "num_pois": len(recommendations),
            "recommendations": recommendations
        }), 200
        
    except FileNotFoundError as e:
        return jsonify({
            "success": False,
            "error": f"Required data file not found: {str(e)}"
        }), 500
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500


@app.route('/itinerary/group', methods=['POST'])
def itinerary_group():
    """
    Group itinerary generation endpoint.
    
    Request body:
    {
        "user_ids": ["USER_000001", "USER_000002", "USER_000003"],
        "method": "ga",  # or "greedy"
        "num_stops": 5
    }
    
    Response:
    {
        "success": true,
        "method": "ga",
        "num_users": 3,
        "num_stops": 5,
        "total_cost": 1050.70,
        "fitness": 0.3147,  # only for GA
        "itinerary": [
            {
                "stop_number": 1,
                "poi_id": "POI_031",
                "final_group_score": 0.4088,
                "leg_cost_from_previous": 0.0,
                "cumulative_cost": 0.0
            },
            ...
        ]
    }
    """
    try:
        # Parse request
        data = request.get_json()
        
        if not data:
            return jsonify({
                "success": False,
                "error": "No JSON data provided"
            }), 400
        
        user_ids = data.get('user_ids', [])
        method = data.get('method', 'ga').lower()
        num_stops = data.get('num_stops', 5)
        
        # Validate inputs
        valid, error_msg = validate_user_ids(user_ids)
        if not valid:
            return jsonify({
                "success": False,
                "error": error_msg
            }), 400
        
        valid, error_msg = validate_method(method)
        if not valid:
            return jsonify({
                "success": False,
                "error": error_msg
            }), 400
        
        if not isinstance(num_stops, int) or num_stops < 2:
            return jsonify({
                "success": False,
                "error": "num_stops must be an integer >= 2"
            }), 400
        
        # Step 1: Run group recommendations
        # Use more candidates than needed for itinerary
        candidate_pool_size = max(15, num_stops * 2)
        group_recs = run_group_recommendations(user_ids, candidate_pool_size)
        
        # Save recommendations for itinerary builders
        save_temp_group_recommendations(group_recs)
        
        # Step 2: Build itinerary based on method
        if method == 'greedy':
            itinerary_df = run_greedy_itinerary(num_stops)
            fitness = None
            
        else:  # method == 'ga'
            itinerary_df, fitness = run_ga_itinerary(num_stops)
        
        # Extract metrics
        total_cost = float(itinerary_df['cumulative_cost'].iloc[-1])
        
        # Convert to JSON-safe format
        itinerary = dataframe_to_json_safe(itinerary_df)
        
        # Build response
        response = {
            "success": True,
            "method": method,
            "num_users": len(user_ids),
            "num_stops": len(itinerary),
            "total_cost": round(total_cost, 2),
            "itinerary": itinerary
        }
        
        # Add fitness for GA
        if fitness is not None:
            response["fitness"] = round(float(fitness), 4)
        
        return jsonify(response), 200
        
    except FileNotFoundError as e:
        return jsonify({
            "success": False,
            "error": f"Required data file not found: {str(e)}"
        }), 500
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500


# ============================================================================
# Error Handlers
# ============================================================================

@app.route('/evaluate/place', methods=['POST'])
def evaluate_place():
    """Lightweight evaluator used by FastAPI to score a single suggested place.

    The model in this repo only operates over its own synthetic POI dataset,
    so this endpoint does NOT call the model. It returns a deterministic
    suitability score derived from the place's metadata so the suggestions
    pipeline has something better than the previous fixed-0.75 stub.

    Request body:
    {
        "name": str,
        "rating": float | null,
        "user_ratings_total": int | null,
        "place_types": [str, ...],
        "trip_destination": str | null
    }

    Response:
    {
        "success": true,
        "ai_score": float (0..1),
        "ai_reasoning": str
    }
    """
    try:
        data = request.get_json() or {}
        name = data.get("name") or "Place"
        rating = float(data.get("rating") or 0.0)
        ratings_total = int(data.get("user_ratings_total") or 0)
        place_types = [str(t).lower() for t in (data.get("place_types") or [])]

        TRAVEL_FRIENDLY = {
            "tourist_attraction", "landmark", "museum", "park", "beach",
            "restaurant", "cafe", "shopping_mall", "art_gallery", "amusement_park",
            "aquarium", "zoo", "natural_feature", "place_of_worship", "mosque",
        }
        DOWNWEIGHT = {"hospital", "doctor", "lawyer", "atm", "bank", "gas_station"}

        score = 0.0
        reasons = []

        rating_part = max(0.0, min(rating / 5.0, 1.0)) * 0.55
        score += rating_part
        if rating > 0:
            reasons.append(f"rating={rating:.1f}")

        if ratings_total > 0:
            popularity = min(1.0, ratings_total / 1500.0) * 0.20
            score += popularity
            reasons.append(f"reviews={ratings_total}")

        type_set = set(place_types)
        if type_set & TRAVEL_FRIENDLY:
            score += 0.20
            reasons.append("travel-friendly category")
        if type_set & DOWNWEIGHT:
            score -= 0.40
            reasons.append("category not suitable")

        score = max(0.0, min(1.0, score))

        return jsonify({
            "success": True,
            "ai_score": round(score, 3),
            "ai_reasoning": f"{name}: " + ", ".join(reasons) if reasons else f"{name}: limited info available",
        }), 200
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return jsonify({
        "success": False,
        "error": "Endpoint not found"
    }), 404


@app.errorhandler(405)
def method_not_allowed(error):
    """Handle 405 errors."""
    return jsonify({
        "success": False,
        "error": "Method not allowed"
    }), 405


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors."""
    return jsonify({
        "success": False,
        "error": "Internal server error"
    }), 500


# ============================================================================
# Main Entry Point
# ============================================================================

if __name__ == '__main__':
    print("\n" + "=" * 80)
    print("TripBond AI Backend API Server")
    print("=" * 80)
    print("\nAvailable Endpoints:")
    print("  • GET  /health                 - Health check")
    print("  • POST /recommend/group        - Group POI recommendations")
    print("  • POST /itinerary/group        - Group itinerary generation")
    print("  • POST /evaluate/place         - Score a suggested place (suitability)")
    print("\n" + "=" * 80)
    print("Starting server on http://127.0.0.1:5000")
    print("=" * 80 + "\n")
    
    app.run(host='0.0.0.0', port=5000, debug=True)
