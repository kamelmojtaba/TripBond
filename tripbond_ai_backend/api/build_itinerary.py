"""
TripBond Greedy Itinerary Builder (Phase 1)
============================================
Generates an ordered itinerary from group-recommended POIs using greedy nearest-neighbor.

Author: TripBond AI Team
Date: 2026-02-21
"""

import pandas as pd
import numpy as np
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')


class GreedyItineraryBuilder:
    """Build travel itinerary using greedy nearest-neighbor algorithm."""
    
    def __init__(self, top_n_pois=5):
        """
        Initialize the itinerary builder.
        
        Args:
            top_n_pois: Number of top-scored POIs to include in itinerary
        """
        self.top_n_pois = top_n_pois
        
        # Project paths
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.group_recs_file = self.data_dir / "top_pois_for_group.csv"
        self.routes_file = self.data_dir / "tourism_dynamic_routes_FINAL_MODEL_READY.csv"
        self.output_file = self.data_dir / "group_itinerary_greedy.csv"
        
        # Data containers
        self.group_recs_df = None
        self.routes_df = None
        self.selected_pois = None
        self.itinerary = None
        
        # Detected column names
        self.poi_id_col = None
        self.score_col = None
        self.lat_col = None
        self.lon_col = None
        self.route_source_col = None
        self.route_dest_col = None
        self.route_cost_col = None
    
    def load_data(self):
        """Load group recommendations and routes datasets."""
        print("\n" + "=" * 80)
        print("TripBond Greedy Itinerary Builder - Phase 1")
        print("=" * 80)
        print("\n[STEP 1] Loading datasets...")
        
        # Load group recommendations
        if not self.group_recs_file.exists():
            raise FileNotFoundError(f"Group recommendations not found: {self.group_recs_file}")
        
        self.group_recs_df = pd.read_csv(self.group_recs_file)
        print(f"[INFO] ✓ Loaded group recommendations: {self.group_recs_df.shape}")
        print(f"[INFO]   Columns: {list(self.group_recs_df.columns)}")
        
        # Load routes
        if not self.routes_file.exists():
            raise FileNotFoundError(f"Routes dataset not found: {self.routes_file}")
        
        self.routes_df = pd.read_csv(self.routes_file)
        print(f"[INFO] ✓ Loaded routes dataset: {self.routes_df.shape}")
        print(f"[INFO]   Columns: {list(self.routes_df.columns)}")
    
    def detect_columns(self):
        """Dynamically detect column names in both datasets."""
        print("\n[STEP 2] Detecting column names...")
        
        # Detect POI ID column
        poi_id_candidates = ['poi_id', 'POI_ID', 'id', 'ID', 'place_id']
        for candidate in poi_id_candidates:
            if candidate in self.group_recs_df.columns:
                self.poi_id_col = candidate
                break
        
        if not self.poi_id_col:
            # Use first column as fallback
            self.poi_id_col = self.group_recs_df.columns[0]
            print(f"[WARNING] Using first column as POI ID: {self.poi_id_col}")
        else:
            print(f"[INFO] ✓ Detected POI ID column: {self.poi_id_col}")
        
        # Detect group score column
        score_candidates = ['final_group_score', 'group_score', 'score', 'rating', 'Score']
        for candidate in score_candidates:
            if candidate in self.group_recs_df.columns:
                self.score_col = candidate
                break
        
        if not self.score_col:
            raise ValueError("Could not detect group score column")
        print(f"[INFO] ✓ Detected score column: {self.score_col}")
        
        # Detect latitude/longitude columns
        lat_candidates = ['poi_latitude', 'latitude', 'lat', 'Latitude', 'LAT']
        lon_candidates = ['poi_longitude', 'longitude', 'lon', 'lng', 'Longitude', 'LON']
        
        for candidate in lat_candidates:
            if candidate in self.group_recs_df.columns:
                self.lat_col = candidate
                break
        
        for candidate in lon_candidates:
            if candidate in self.group_recs_df.columns:
                self.lon_col = candidate
                break
        
        if self.lat_col and self.lon_col:
            print(f"[INFO] ✓ Detected coordinates: {self.lat_col}, {self.lon_col}")
        else:
            print("[WARNING] Coordinates not detected - Haversine fallback unavailable")
        
        # Detect route source column
        source_candidates = ['source', 'from', 'origin', 'source_poi', 'from_poi', 'Source']
        for candidate in source_candidates:
            if candidate in self.routes_df.columns:
                self.route_source_col = candidate
                break
        
        if not self.route_source_col:
            self.route_source_col = self.routes_df.columns[0]
            print(f"[WARNING] Using first column as route source: {self.route_source_col}")
        else:
            print(f"[INFO] ✓ Detected route source column: {self.route_source_col}")
        
        # Detect route destination column
        dest_candidates = ['destination', 'dest', 'to', 'target', 'destination_poi', 'to_poi', 'Destination']
        for candidate in dest_candidates:
            if candidate in self.routes_df.columns:
                self.route_dest_col = candidate
                break
        
        if not self.route_dest_col:
            self.route_dest_col = self.routes_df.columns[1]
            print(f"[WARNING] Using second column as route destination: {self.route_dest_col}")
        else:
            print(f"[INFO] ✓ Detected route destination column: {self.route_dest_col}")
        
        # Detect cost column (prefer travel time over distance)
        time_candidates = ['travel_time', 'time', 'duration', 'travel_duration', 
                          'Travel_Time', 'TIME', 'time_minutes']
        distance_candidates = ['distance', 'dist', 'travel_distance', 'Distance', 'DIST']
        
        for candidate in time_candidates:
            if candidate in self.routes_df.columns:
                self.route_cost_col = candidate
                break
        
        if not self.route_cost_col:
            for candidate in distance_candidates:
                if candidate in self.routes_df.columns:
                    self.route_cost_col = candidate
                    break
        
        if not self.route_cost_col:
            # Use first numeric column after source and dest
            numeric_cols = self.routes_df.select_dtypes(include=[np.number]).columns
            for col in numeric_cols:
                if col not in [self.route_source_col, self.route_dest_col]:
                    self.route_cost_col = col
                    break
        
        if not self.route_cost_col:
            raise ValueError("Could not detect route cost column")
        print(f"[INFO] ✓ Detected route cost column: {self.route_cost_col}")
    
    def select_top_pois(self):
        """Select top N POIs based on group score."""
        print(f"\n[STEP 3] Selecting top {self.top_n_pois} POIs by group score...")
        
        # Sort by score descending and take top N
        self.selected_pois = self.group_recs_df.nlargest(
            self.top_n_pois, 
            self.score_col
        ).copy()
        
        print(f"[INFO] ✓ Selected {len(self.selected_pois)} POIs")
        print("\n[INFO] Selected POIs:")
        for idx, row in self.selected_pois.iterrows():
            poi_id = row[self.poi_id_col]
            score = row[self.score_col]
            print(f"  • {poi_id}: {score:.4f}")
    
    def get_route_cost(self, from_poi, to_poi):
        """
        Get travel cost between two POIs from routes dataset.
        
        Args:
            from_poi: Source POI identifier
            to_poi: Destination POI identifier
            
        Returns:
            float: Travel cost, or None if route not found
        """
        route = self.routes_df[
            (self.routes_df[self.route_source_col] == from_poi) & 
            (self.routes_df[self.route_dest_col] == to_poi)
        ]
        
        if not route.empty:
            return route.iloc[0][self.route_cost_col]
        
        return None
    
    def haversine_distance(self, lat1, lon1, lat2, lon2):
        """
        Calculate Haversine distance between two coordinates in kilometers.
        
        Args:
            lat1, lon1: First point coordinates
            lat2, lon2: Second point coordinates
            
        Returns:
            float: Distance in kilometers
        """
        R = 6371  # Earth radius in kilometers
        
        # Convert to radians
        lat1, lon1, lat2, lon2 = map(np.radians, [lat1, lon1, lat2, lon2])
        
        # Haversine formula
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = np.sin(dlat/2)**2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon/2)**2
        c = 2 * np.arcsin(np.sqrt(a))
        
        return R * c
    
    def get_travel_cost(self, from_poi_id, to_poi_id):
        """
        Get travel cost between two POIs, with Haversine fallback.
        
        Args:
            from_poi_id: Source POI identifier
            to_poi_id: Destination POI identifier
            
        Returns:
            tuple: (cost, is_haversine_fallback)
        """
        # Try to get from routes dataset
        cost = self.get_route_cost(from_poi_id, to_poi_id)
        
        if cost is not None:
            return cost, False
        
        # Fallback to Haversine if coordinates available
        if self.lat_col and self.lon_col:
            from_poi = self.selected_pois[
                self.selected_pois[self.poi_id_col] == from_poi_id
            ].iloc[0]
            to_poi = self.selected_pois[
                self.selected_pois[self.poi_id_col] == to_poi_id
            ].iloc[0]
            
            if pd.notna(from_poi[self.lat_col]) and pd.notna(to_poi[self.lat_col]):
                distance = self.haversine_distance(
                    from_poi[self.lat_col], from_poi[self.lon_col],
                    to_poi[self.lat_col], to_poi[self.lon_col]
                )
                return distance, True
        
        # If all else fails, return a large penalty
        return 999999, True
    
    def build_greedy_itinerary(self):
        """Build itinerary using greedy nearest-neighbor algorithm."""
        print("\n[STEP 4] Building greedy itinerary...")
        
        # Get POI IDs and scores
        poi_ids = self.selected_pois[self.poi_id_col].tolist()
        poi_scores = dict(zip(
            self.selected_pois[self.poi_id_col], 
            self.selected_pois[self.score_col]
        ))
        
        # Start from highest-scored POI
        current_poi = poi_ids[0]
        unvisited = set(poi_ids[1:])
        
        # Initialize itinerary tracking
        itinerary_data = []
        cumulative_cost = 0.0
        
        # Add first stop
        itinerary_data.append({
            'stop_number': 1,
            'poi_id': current_poi,
            'final_group_score': poi_scores[current_poi],
            'leg_cost_from_previous': 0.0,
            'cumulative_cost': 0.0,
            'is_haversine_estimate': False
        })
        
        print(f"\n[INFO] Starting POI: {current_poi} (score: {poi_scores[current_poi]:.4f})")
        
        # Greedy selection: always pick nearest unvisited POI
        stop_num = 2
        while unvisited:
            # Find nearest unvisited POI
            min_cost = float('inf')
            next_poi = None
            is_haversine = False
            
            for candidate in unvisited:
                cost, haversine_used = self.get_travel_cost(current_poi, candidate)
                if cost < min_cost:
                    min_cost = cost
                    next_poi = candidate
                    is_haversine = haversine_used
            
            # Move to next POI
            cumulative_cost += min_cost
            itinerary_data.append({
                'stop_number': stop_num,
                'poi_id': next_poi,
                'final_group_score': poi_scores[next_poi],
                'leg_cost_from_previous': min_cost,
                'cumulative_cost': cumulative_cost,
                'is_haversine_estimate': is_haversine
            })
            
            fallback_label = " (Haversine)" if is_haversine else ""
            print(f"[INFO] Stop {stop_num}: {next_poi} "
                  f"(cost: {min_cost:.2f}{fallback_label}, "
                  f"score: {poi_scores[next_poi]:.4f})")
            
            # Update state
            unvisited.remove(next_poi)
            current_poi = next_poi
            stop_num += 1
        
        # Create itinerary DataFrame
        self.itinerary = pd.DataFrame(itinerary_data)
        
        print(f"\n[INFO] ✓ Greedy itinerary built")
        print(f"[INFO]   Total stops: {len(self.itinerary)}")
        print(f"[INFO]   Total cost: {cumulative_cost:.2f}")
    
    def display_itinerary(self):
        """Display the itinerary in a nicely formatted table."""
        print("\n" + "=" * 80)
        print("FINAL ITINERARY - Greedy Nearest-Neighbor")
        print("=" * 80)
        
        print(f"\n{'Stop':<6} {'POI ID':<20} {'Score':<8} {'Leg Cost':<12} "
              f"{'Cumulative':<12} {'Method':<10}")
        print("-" * 80)
        
        for _, row in self.itinerary.iterrows():
            method = "Haversine" if row['is_haversine_estimate'] else "Route"
            leg_cost_str = f"{row['leg_cost_from_previous']:.2f}" if row['stop_number'] > 1 else "-"
            
            print(f"{row['stop_number']:<6} "
                  f"{str(row['poi_id']):<20} "
                  f"{row['final_group_score']:.4f}  "
                  f"{leg_cost_str:<12} "
                  f"{row['cumulative_cost']:.2f}      "
                  f"{method:<10}")
        
        print("-" * 80)
        print(f"Total Travel Cost: {self.itinerary['cumulative_cost'].iloc[-1]:.2f}")
        print(f"Average POI Score: {self.itinerary['final_group_score'].mean():.4f}")
        
        # Count Haversine fallbacks
        haversine_count = self.itinerary['is_haversine_estimate'].sum()
        if haversine_count > 0:
            print(f"\n[NOTE] {haversine_count} leg(s) estimated using Haversine distance")
    
    def save_itinerary(self):
        """Save the itinerary to CSV."""
        print("\n[STEP 5] Saving itinerary...")
        
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.itinerary.to_csv(self.output_file, index=False)
        
        print(f"[SUCCESS] ✓ Itinerary saved to: {self.output_file}")
        print(f"[SUCCESS]   Rows: {len(self.itinerary)}")
        print(f"[SUCCESS]   Columns: {list(self.itinerary.columns)}")
    
    def run(self):
        """Execute the complete itinerary building pipeline."""
        try:
            # Load data
            self.load_data()
            
            # Detect columns
            self.detect_columns()
            
            # Select top POIs
            self.select_top_pois()
            
            # Build itinerary
            self.build_greedy_itinerary()
            
            # Display results
            self.display_itinerary()
            
            # Save output
            self.save_itinerary()
            
            print("\n" + "=" * 80)
            print("Pipeline Complete - Phase 1 Itinerary Generated")
            print("=" * 80)
            print("\n[NEXT] Phase 2: Implement Genetic Algorithm for optimization")
            
            return self.itinerary
            
        except Exception as e:
            print(f"\n[ERROR] Pipeline failed: {str(e)}")
            raise


def main():
    """Main execution function."""
    builder = GreedyItineraryBuilder(top_n_pois=5)
    itinerary = builder.run()


if __name__ == "__main__":
    main()
