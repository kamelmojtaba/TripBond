"""
OpenRouteService Routing Integration for TripBond
==================================================
Computes real travel-time matrices between POIs using OpenRouteService Matrix API.
Includes caching, fallback to Haversine distance, and error handling.

Author: TripBond AI Team
Date: 2026-02-21
Target City: Al Khobar, Saudi Arabia
"""

import os
import json
import time
import requests
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')


class ORSMatrixClient:
    """OpenRouteService Matrix API client with caching and fallback."""
    
    def __init__(self, api_key=None, cache_expiry_hours=24):
        """
        Initialize ORS Matrix client.
        
        Args:
            api_key: ORS API key (defaults to ORS_API_KEY env variable)
            cache_expiry_hours: Cache validity duration in hours
        """
        self.api_key = api_key or os.getenv('ORS_API_KEY')
        self.cache_expiry_hours = cache_expiry_hours
        
        # Project paths
        self.project_root = Path(__file__).parent.parent
        self.cache_dir = self.project_root / "cache"
        self.cache_file = self.cache_dir / "ors_matrix_khobar.json"
        
        # ORS API endpoint
        self.api_url = "https://api.openrouteservice.org/v2/matrix/driving-car"
        
        # Request configuration
        self.timeout = 30
        self.max_retries = 3
        self.retry_delay = 2
    
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
    
    def distance_to_travel_time(self, distance_km):
        """
        Convert distance to estimated travel time.
        Uses average urban speed of 40 km/h.
        
        Args:
            distance_km: Distance in kilometers
            
        Returns:
            float: Travel time in seconds
        """
        avg_speed_kmh = 40.0
        hours = distance_km / avg_speed_kmh
        return hours * 3600.0
    
    def compute_haversine_matrix(self, pois_df):
        """
        Compute fallback travel-time matrix using Haversine distance.
        
        Args:
            pois_df: DataFrame with poi_id, poi_latitude, poi_longitude
            
        Returns:
            tuple: (dict, DataFrame) - travel time dict and matrix
        """
        print("[FALLBACK] Computing travel times using Haversine distance...")
        
        poi_ids = pois_df['poi_id'].tolist()
        n = len(poi_ids)
        
        # Initialize matrix
        matrix = np.zeros((n, n))
        travel_dict = {}
        
        for i, poi_i in pois_df.iterrows():
            for j, poi_j in pois_df.iterrows():
                if i == j:
                    travel_time = 0.0
                else:
                    # Calculate Haversine distance
                    distance = self.haversine_distance(
                        poi_i['poi_latitude'], poi_i['poi_longitude'],
                        poi_j['poi_latitude'], poi_j['poi_longitude']
                    )
                    # Convert to travel time
                    travel_time = self.distance_to_travel_time(distance)
                
                matrix[i, j] = travel_time
                travel_dict[(poi_i['poi_id'], poi_j['poi_id'])] = travel_time
        
        # Create DataFrame
        matrix_df = pd.DataFrame(matrix, index=poi_ids, columns=poi_ids)
        
        print(f"[FALLBACK] ✓ Computed {len(travel_dict)} travel times")
        return travel_dict, matrix_df
    
    def load_cache(self):
        """
        Load cached travel-time matrix if valid.
        
        Returns:
            dict or None: Cached data if valid, None otherwise
        """
        if not self.cache_file.exists():
            return None
        
        try:
            with open(self.cache_file, 'r') as f:
                cache_data = json.load(f)
            
            # Check cache timestamp
            cached_time = datetime.fromisoformat(cache_data.get('timestamp'))
            expiry_time = cached_time + timedelta(hours=self.cache_expiry_hours)
            
            if datetime.now() < expiry_time:
                print(f"[CACHE] ✓ Using cached matrix (age: {(datetime.now() - cached_time).seconds // 3600}h)")
                return cache_data
            else:
                print("[CACHE] Cache expired, will fetch fresh data")
                return None
                
        except Exception as e:
            print(f"[CACHE] Error loading cache: {str(e)}")
            return None
    
    def save_cache(self, travel_dict, poi_ids):
        """
        Save travel-time matrix to cache.
        
        Args:
            travel_dict: Dictionary of travel times
            poi_ids: List of POI IDs
        """
        try:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
            
            # Convert tuple keys to strings for JSON serialization
            serializable_dict = {
                f"{k[0]}|{k[1]}": v for k, v in travel_dict.items()
            }
            
            cache_data = {
                'timestamp': datetime.now().isoformat(),
                'poi_ids': poi_ids,
                'travel_times': serializable_dict,
                'source': 'ors_api'
            }
            
            with open(self.cache_file, 'w') as f:
                json.dump(cache_data, f, indent=2)
            
            print(f"[CACHE] ✓ Saved matrix to cache: {self.cache_file}")
            
        except Exception as e:
            print(f"[CACHE] Warning: Could not save cache: {str(e)}")
    
    def parse_cached_data(self, cache_data, pois_df):
        """
        Parse cached data into travel_dict and matrix_df.
        
        Args:
            cache_data: Cached data dictionary
            pois_df: DataFrame with current POIs
            
        Returns:
            tuple or None: (travel_dict, matrix_df) or None if invalid
        """
        try:
            cached_poi_ids = set(cache_data['poi_ids'])
            current_poi_ids = set(pois_df['poi_id'].tolist())
            
            # Check if all current POIs are in cache
            if not current_poi_ids.issubset(cached_poi_ids):
                print("[CACHE] Current POIs not fully covered by cache")
                return None
            
            # Reconstruct travel_dict
            travel_dict = {}
            for key_str, value in cache_data['travel_times'].items():
                poi_a, poi_b = key_str.split('|')
                if poi_a in current_poi_ids and poi_b in current_poi_ids:
                    travel_dict[(poi_a, poi_b)] = value
            
            # Build matrix DataFrame
            poi_ids = pois_df['poi_id'].tolist()
            n = len(poi_ids)
            matrix = np.zeros((n, n))
            
            for i, poi_i in enumerate(poi_ids):
                for j, poi_j in enumerate(poi_ids):
                    matrix[i, j] = travel_dict.get((poi_i, poi_j), 0.0)
            
            matrix_df = pd.DataFrame(matrix, index=poi_ids, columns=poi_ids)
            
            return travel_dict, matrix_df
            
        except Exception as e:
            print(f"[CACHE] Error parsing cache: {str(e)}")
            return None
    
    def call_ors_api(self, coordinates):
        """
        Call ORS Matrix API with retry logic.
        
        Args:
            coordinates: List of [lon, lat] pairs
            
        Returns:
            dict: API response data or None on failure
        """
        if not self.api_key:
            print("[ERROR] ORS_API_KEY not found in environment variables")
            return None
        
        headers = {
            'Authorization': self.api_key,
            'Content-Type': 'application/json'
        }
        
        payload = {
            'locations': coordinates,
            'metrics': ['duration'],
            'units': 'm'
        }
        
        for attempt in range(self.max_retries):
            try:
                print(f"[ORS] Calling Matrix API (attempt {attempt + 1}/{self.max_retries})...")
                
                response = requests.post(
                    self.api_url,
                    headers=headers,
                    json=payload,
                    timeout=self.timeout
                )
                
                # Check for rate limit
                if response.status_code == 429:
                    print(f"[ORS] Rate limit hit, waiting {self.retry_delay}s...")
                    time.sleep(self.retry_delay)
                    continue
                
                # Check for success
                if response.status_code == 200:
                    return response.json()
                
                # Other errors
                print(f"[ORS] API error {response.status_code}: {response.text[:200]}")
                
                if attempt < self.max_retries - 1:
                    time.sleep(self.retry_delay)
                    
            except requests.exceptions.Timeout:
                print(f"[ORS] Request timeout (attempt {attempt + 1})")
                if attempt < self.max_retries - 1:
                    time.sleep(self.retry_delay)
                    
            except requests.exceptions.RequestException as e:
                print(f"[ORS] Request failed: {str(e)}")
                if attempt < self.max_retries - 1:
                    time.sleep(self.retry_delay)
        
        return None
    
    def build_travel_matrix(self, pois_df):
        """
        Build travel-time matrix from ORS API or cache.
        
        Args:
            pois_df: DataFrame with poi_id, poi_latitude, poi_longitude
            
        Returns:
            tuple: (travel_dict, matrix_df)
                  - travel_dict: {(poi_a, poi_b): travel_time_seconds}
                  - matrix_df: DataFrame with poi_ids as index/columns
        """
        print("\n" + "=" * 70)
        print("OpenRouteService Travel-Time Matrix Builder")
        print("=" * 70)
        
        # Validate input
        required_cols = ['poi_id', 'poi_latitude', 'poi_longitude']
        for col in required_cols:
            if col not in pois_df.columns:
                raise ValueError(f"Required column '{col}' not found in input DataFrame")
        
        # Check POI count
        n_pois = len(pois_df)
        if n_pois > 20:
            print(f"[WARNING] {n_pois} POIs provided, but max is 20. Using first 20.")
            pois_df = pois_df.head(20)
            n_pois = 20
        
        print(f"[INFO] Building matrix for {n_pois} POIs")
        
        # Try loading from cache
        cache_data = self.load_cache()
        if cache_data:
            result = self.parse_cached_data(cache_data, pois_df)
            if result:
                travel_dict, matrix_df = result
                print(f"[SUCCESS] ✓ Loaded {len(travel_dict)} travel times from cache")
                return travel_dict, matrix_df
        
        # Prepare coordinates for ORS API [lon, lat]
        coordinates = [
            [row['poi_longitude'], row['poi_latitude']]
            for _, row in pois_df.iterrows()
        ]
        
        # Call ORS API
        response_data = self.call_ors_api(coordinates)
        
        # Check if API call succeeded
        if response_data is None or 'durations' not in response_data:
            print("[ERROR] ORS API call failed, using Haversine fallback")
            return self.compute_haversine_matrix(pois_df)
        
        # Parse API response
        print("[ORS] ✓ API call successful, parsing response...")
        
        durations = response_data['durations']
        poi_ids = pois_df['poi_id'].tolist()
        
        # Build travel_dict and matrix
        travel_dict = {}
        matrix = np.array(durations)
        
        for i, poi_i in enumerate(poi_ids):
            for j, poi_j in enumerate(poi_ids):
                travel_time = durations[i][j] if durations[i][j] is not None else 0.0
                travel_dict[(poi_i, poi_j)] = travel_time
        
        matrix_df = pd.DataFrame(matrix, index=poi_ids, columns=poi_ids)
        
        print(f"[SUCCESS] ✓ Built matrix with {len(travel_dict)} travel times")
        
        # Save to cache
        self.save_cache(travel_dict, poi_ids)
        
        return travel_dict, matrix_df
    
    def get_travel_time(self, travel_dict, poi_a, poi_b):
        """
        Get travel time between two POIs from travel_dict.
        
        Args:
            travel_dict: Dictionary of travel times
            poi_a: Source POI ID
            poi_b: Destination POI ID
            
        Returns:
            float: Travel time in seconds
        """
        return travel_dict.get((poi_a, poi_b), 0.0)


def demo_matrix_builder():
    """
    Demo function that loads top POIs and builds travel-time matrix.
    """
    print("\n" + "=" * 70)
    print("ORS Matrix Builder Demo")
    print("=" * 70)
    
    # Paths
    project_root = Path(__file__).parent.parent
    data_dir = project_root / "data"
    group_recs_file = data_dir / "top_pois_for_group.csv"
    
    # Load group recommendations
    if not group_recs_file.exists():
        print(f"[ERROR] File not found: {group_recs_file}")
        print("[INFO] Please run group recommendations first")
        return
    
    print(f"[INFO] Loading POIs from: {group_recs_file}")
    df = pd.read_csv(group_recs_file)
    
    # Select top 10 POIs
    top_n = 10
    if 'final_group_score' in df.columns:
        df = df.nlargest(top_n, 'final_group_score')
    else:
        df = df.head(top_n)
    
    print(f"[INFO] Selected top {len(df)} POIs")
    
    # Verify required columns
    required_cols = ['poi_id', 'poi_latitude', 'poi_longitude']
    missing_cols = [col for col in required_cols if col not in df.columns]
    
    if missing_cols:
        print(f"[ERROR] Missing required columns: {missing_cols}")
        return
    
    # Initialize ORS client
    client = ORSMatrixClient()
    
    # Build matrix
    try:
        travel_dict, matrix_df = client.build_travel_matrix(df)
        
        # Extract non-zero travel times (exclude diagonal)
        travel_times = [
            v for (src, dst), v in travel_dict.items()
            if src != dst and v > 0
        ]
        
        if travel_times:
            print("\n" + "=" * 70)
            print("Travel Time Statistics")
            print("=" * 70)
            print(f"Total POI pairs: {len(travel_times)}")
            print(f"Min travel time:  {min(travel_times):.2f} seconds ({min(travel_times)/60:.2f} min)")
            print(f"Mean travel time: {np.mean(travel_times):.2f} seconds ({np.mean(travel_times)/60:.2f} min)")
            print(f"Max travel time:  {max(travel_times):.2f} seconds ({max(travel_times)/60:.2f} min)")
            
            print("\n[SAMPLE] Travel times from first POI:")
            first_poi = df.iloc[0]['poi_id']
            for poi_id in df['poi_id'].head(5):
                if poi_id != first_poi:
                    tt = travel_dict.get((first_poi, poi_id), 0)
                    print(f"  {first_poi} → {poi_id}: {tt:.2f}s ({tt/60:.2f} min)")
        
        print("\n" + "=" * 70)
        print("Demo Complete!")
        print("=" * 70)
        
    except Exception as e:
        print(f"\n[ERROR] Demo failed: {str(e)}")
        raise


if __name__ == "__main__":
    # Run demo
    demo_matrix_builder()
