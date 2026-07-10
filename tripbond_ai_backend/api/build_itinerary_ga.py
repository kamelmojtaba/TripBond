"""
TripBond Genetic Algorithm Itinerary Optimizer (Phase 2)
=========================================================
Optimizes travel itinerary using Genetic Algorithm to balance:
- Group recommendation scores
- Travel cost minimization
- Fairness across group members

Author: TripBond AI Team
Date: 2026-02-21
"""

import pandas as pd
import numpy as np
from pathlib import Path
import random
import warnings
warnings.filterwarnings('ignore')


class GeneticItineraryOptimizer:
    """Optimize travel itinerary using Genetic Algorithm."""
    
    def __init__(self, 
                 candidate_pool_size=10,
                 itinerary_size=5,
                 population_size=40,
                 generations=50,
                 tournament_size=3,
                 crossover_rate=0.8,
                 mutation_rate=0.2,
                 random_seed=42):
        """
        Initialize the Genetic Algorithm optimizer.
        
        Args:
            candidate_pool_size: Number of top POIs to consider
            itinerary_size: Number of POIs in final itinerary
            population_size: GA population size
            generations: Number of generations to evolve
            tournament_size: Tournament selection size
            crossover_rate: Probability of crossover
            mutation_rate: Probability of mutation
            random_seed: Random seed for reproducibility
        """
        self.candidate_pool_size = candidate_pool_size
        self.itinerary_size = itinerary_size
        self.population_size = population_size
        self.generations = generations
        self.tournament_size = tournament_size
        self.crossover_rate = crossover_rate
        self.mutation_rate = mutation_rate
        self.random_seed = random_seed
        
        # Set random seeds
        random.seed(random_seed)
        np.random.seed(random_seed)
        
        # Project paths
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.group_recs_file = self.data_dir / "top_pois_for_group.csv"
        self.routes_file = self.data_dir / "tourism_dynamic_routes_FINAL_MODEL_READY.csv"
        self.output_file = self.data_dir / "group_itinerary_ga.csv"
        
        # Data containers
        self.group_recs_df = None
        self.routes_df = None
        self.candidate_pois = None
        self.poi_data = {}  # POI ID -> data dict
        
        # Column names
        self.poi_id_col = None
        self.score_col = None
        self.fairness_col = None
        self.lat_col = None
        self.lon_col = None
        self.route_source_col = None
        self.route_dest_col = None
        self.route_cost_col = None
        
        # GA results
        self.population = []
        self.best_chromosome = None
        self.best_fitness = -float('inf')
        self.fitness_history = []
    
    def load_data(self):
        """Load group recommendations and routes datasets."""
        print("\n" + "=" * 80)
        print("TripBond Genetic Algorithm Itinerary Optimizer - Phase 2")
        print("=" * 80)
        print("\n[STEP 1] Loading datasets...")
        
        # Load group recommendations
        if not self.group_recs_file.exists():
            raise FileNotFoundError(f"Group recommendations not found: {self.group_recs_file}")
        
        self.group_recs_df = pd.read_csv(self.group_recs_file)
        print(f"[INFO] ✓ Loaded group recommendations: {self.group_recs_df.shape}")
        
        # Load routes
        if not self.routes_file.exists():
            raise FileNotFoundError(f"Routes dataset not found: {self.routes_file}")
        
        self.routes_df = pd.read_csv(self.routes_file)
        print(f"[INFO] ✓ Loaded routes dataset: {self.routes_df.shape}")
    
    def detect_columns(self):
        """Dynamically detect column names."""
        print("\n[STEP 2] Detecting column names...")
        
        # POI ID
        poi_id_candidates = ['poi_id', 'POI_ID', 'id', 'ID', 'place_id']
        for candidate in poi_id_candidates:
            if candidate in self.group_recs_df.columns:
                self.poi_id_col = candidate
                break
        if not self.poi_id_col:
            self.poi_id_col = self.group_recs_df.columns[0]
        print(f"[INFO] ✓ POI ID column: {self.poi_id_col}")
        
        # Group score
        score_candidates = ['final_group_score', 'group_score', 'score', 'rating']
        for candidate in score_candidates:
            if candidate in self.group_recs_df.columns:
                self.score_col = candidate
                break
        if not self.score_col:
            raise ValueError("Could not detect group score column")
        print(f"[INFO] ✓ Score column: {self.score_col}")
        
        # Fairness score (optional)
        fairness_candidates = ['fairness_score', 'fairness', 'min_score']
        for candidate in fairness_candidates:
            if candidate in self.group_recs_df.columns:
                self.fairness_col = candidate
                break
        if self.fairness_col:
            print(f"[INFO] ✓ Fairness column: {self.fairness_col}")
        else:
            print("[INFO] Fairness column not found - will use default")
        
        # Coordinates
        lat_candidates = ['poi_latitude', 'latitude', 'lat', 'Latitude']
        lon_candidates = ['poi_longitude', 'longitude', 'lon', 'lng', 'Longitude']
        
        for candidate in lat_candidates:
            if candidate in self.group_recs_df.columns:
                self.lat_col = candidate
                break
        for candidate in lon_candidates:
            if candidate in self.group_recs_df.columns:
                self.lon_col = candidate
                break
        
        if self.lat_col and self.lon_col:
            print(f"[INFO] ✓ Coordinates: {self.lat_col}, {self.lon_col}")
        
        # Routes columns
        source_candidates = ['source', 'from', 'origin', 'source_poi']
        dest_candidates = ['destination', 'dest', 'to', 'target', 'destination_poi']
        time_candidates = ['travel_time', 'time', 'duration', 'travel_duration']
        distance_candidates = ['distance', 'dist', 'travel_distance']
        
        for candidate in source_candidates:
            if candidate in self.routes_df.columns:
                self.route_source_col = candidate
                break
        if not self.route_source_col:
            self.route_source_col = self.routes_df.columns[0]
        
        for candidate in dest_candidates:
            if candidate in self.routes_df.columns:
                self.route_dest_col = candidate
                break
        if not self.route_dest_col:
            self.route_dest_col = self.routes_df.columns[1]
        
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
            numeric_cols = self.routes_df.select_dtypes(include=[np.number]).columns
            for col in numeric_cols:
                if col not in [self.route_source_col, self.route_dest_col]:
                    self.route_cost_col = col
                    break
        
        print(f"[INFO] ✓ Route columns: {self.route_source_col} -> {self.route_dest_col} ({self.route_cost_col})")
    
    def select_candidate_pool(self):
        """Select top N POIs as candidate pool."""
        print(f"\n[STEP 3] Selecting top {self.candidate_pool_size} POIs as candidate pool...")
        
        self.candidate_pois = self.group_recs_df.nlargest(
            self.candidate_pool_size, 
            self.score_col
        ).copy()
        
        # Store POI data for quick lookup
        for _, row in self.candidate_pois.iterrows():
            poi_id = row[self.poi_id_col]
            self.poi_data[poi_id] = {
                'score': row[self.score_col],
                'fairness': row[self.fairness_col] if self.fairness_col else row[self.score_col],
                'lat': row[self.lat_col] if self.lat_col and pd.notna(row[self.lat_col]) else None,
                'lon': row[self.lon_col] if self.lon_col and pd.notna(row[self.lon_col]) else None
            }
        
        print(f"[INFO] ✓ Selected {len(self.candidate_pois)} candidate POIs")
        print(f"[INFO] Candidate pool: {list(self.poi_data.keys())}")
    
    def haversine_distance(self, lat1, lon1, lat2, lon2):
        """Calculate Haversine distance in kilometers."""
        R = 6371
        lat1, lon1, lat2, lon2 = map(np.radians, [lat1, lon1, lat2, lon2])
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = np.sin(dlat/2)**2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon/2)**2
        c = 2 * np.arcsin(np.sqrt(a))
        return R * c
    
    def get_route_cost(self, from_poi, to_poi):
        """Get travel cost from routes dataset."""
        route = self.routes_df[
            (self.routes_df[self.route_source_col] == from_poi) & 
            (self.routes_df[self.route_dest_col] == to_poi)
        ]
        if not route.empty:
            return route.iloc[0][self.route_cost_col]
        return None
    
    def get_travel_cost(self, from_poi_id, to_poi_id):
        """Get travel cost with Haversine fallback."""
        # Try routes dataset
        cost = self.get_route_cost(from_poi_id, to_poi_id)
        if cost is not None:
            return cost
        
        # Fallback to Haversine
        from_data = self.poi_data[from_poi_id]
        to_data = self.poi_data[to_poi_id]
        
        if from_data['lat'] and to_data['lat']:
            return self.haversine_distance(
                from_data['lat'], from_data['lon'],
                to_data['lat'], to_data['lon']
            )
        
        return 1000.0  # Large penalty
    
    def calculate_total_travel_cost(self, chromosome):
        """Calculate total travel cost for a chromosome (itinerary)."""
        total_cost = 0.0
        for i in range(len(chromosome) - 1):
            cost = self.get_travel_cost(chromosome[i], chromosome[i + 1])
            total_cost += cost
        return total_cost
    
    def fitness_function(self, chromosome):
        """
        Calculate fitness for a chromosome.
        
        fitness = 0.5 * avg_group_score
                - 0.3 * normalized_travel_cost
                + 0.2 * avg_fairness_score
        """
        # Average group score
        scores = [self.poi_data[poi_id]['score'] for poi_id in chromosome]
        avg_score = np.mean(scores)
        
        # Total travel cost
        total_cost = self.calculate_total_travel_cost(chromosome)
        
        # Normalize cost (using max possible cost as reference)
        # Rough estimate: max cost = 1000 * (n-1)
        max_cost = 1000.0 * (len(chromosome) - 1)
        normalized_cost = total_cost / max_cost
        
        # Average fairness
        fairness_scores = [self.poi_data[poi_id]['fairness'] for poi_id in chromosome]
        avg_fairness = np.mean(fairness_scores)
        
        # Fitness formula
        fitness = (0.5 * avg_score) - (0.3 * normalized_cost) + (0.2 * avg_fairness)
        
        return fitness
    
    def initialize_population(self):
        """Initialize population with random chromosomes."""
        print("\n[STEP 4] Initializing population...")
        
        candidate_ids = list(self.poi_data.keys())
        self.population = []
        
        for _ in range(self.population_size):
            # Random selection and shuffle
            chromosome = random.sample(candidate_ids, self.itinerary_size)
            self.population.append(chromosome)
        
        print(f"[INFO] ✓ Initialized population of {self.population_size} chromosomes")
    
    def tournament_selection(self):
        """Select a chromosome using tournament selection."""
        tournament = random.sample(self.population, self.tournament_size)
        best = max(tournament, key=lambda chrom: self.fitness_function(chrom))
        return best.copy()
    
    def single_point_crossover(self, parent1, parent2):
        """
        Perform single-point crossover ensuring unique POIs.
        Uses partially mapped crossover (PMX) variant to maintain uniqueness.
        """
        if random.random() > self.crossover_rate:
            return parent1.copy(), parent2.copy()
        
        # Single crossover point
        point = random.randint(1, len(parent1) - 1)
        
        # Create offspring
        child1 = parent1[:point]
        child2 = parent2[:point]
        
        # Add remaining unique POIs from other parent
        for poi in parent2:
            if poi not in child1 and len(child1) < self.itinerary_size:
                child1.append(poi)
        
        for poi in parent1:
            if poi not in child2 and len(child2) < self.itinerary_size:
                child2.append(poi)
        
        return child1, child2
    
    def swap_mutation(self, chromosome):
        """Mutate chromosome by swapping two POIs."""
        if random.random() > self.mutation_rate:
            return chromosome
        
        # Swap two random positions
        idx1, idx2 = random.sample(range(len(chromosome)), 2)
        chromosome[idx1], chromosome[idx2] = chromosome[idx2], chromosome[idx1]
        
        return chromosome
    
    def evolve(self):
        """Run the genetic algorithm evolution."""
        print(f"\n[STEP 5] Running Genetic Algorithm ({self.generations} generations)...")
        print(f"[INFO] Parameters: pop={self.population_size}, "
              f"crossover={self.crossover_rate}, mutation={self.mutation_rate}")
        
        for generation in range(self.generations):
            # Evaluate fitness
            fitnesses = [self.fitness_function(chrom) for chrom in self.population]
            
            # Track best
            max_fitness = max(fitnesses)
            if max_fitness > self.best_fitness:
                best_idx = fitnesses.index(max_fitness)
                self.best_fitness = max_fitness
                self.best_chromosome = self.population[best_idx].copy()
            
            self.fitness_history.append(max_fitness)
            
            # Print progress every 10 generations
            if (generation + 1) % 10 == 0:
                avg_fitness = np.mean(fitnesses)
                print(f"[GEN {generation + 1:3d}] Best: {max_fitness:.4f}, "
                      f"Avg: {avg_fitness:.4f}, "
                      f"Overall Best: {self.best_fitness:.4f}")
            
            # Create next generation
            new_population = []
            
            # Elitism: keep best chromosome
            new_population.append(self.best_chromosome.copy())
            
            # Generate rest of population
            while len(new_population) < self.population_size:
                # Selection
                parent1 = self.tournament_selection()
                parent2 = self.tournament_selection()
                
                # Crossover
                child1, child2 = self.single_point_crossover(parent1, parent2)
                
                # Mutation
                child1 = self.swap_mutation(child1)
                child2 = self.swap_mutation(child2)
                
                new_population.append(child1)
                if len(new_population) < self.population_size:
                    new_population.append(child2)
            
            self.population = new_population
        
        print(f"\n[INFO] ✓ Evolution complete")
        print(f"[INFO] Best fitness achieved: {self.best_fitness:.4f}")
    
    def build_itinerary_from_chromosome(self, chromosome):
        """Convert best chromosome to ordered itinerary DataFrame."""
        print("\n[STEP 6] Building final itinerary...")
        
        itinerary_data = []
        cumulative_cost = 0.0
        
        for i, poi_id in enumerate(chromosome):
            if i == 0:
                leg_cost = 0.0
            else:
                leg_cost = self.get_travel_cost(chromosome[i-1], poi_id)
                cumulative_cost += leg_cost
            
            itinerary_data.append({
                'stop_number': i + 1,
                'poi_id': poi_id,
                'final_group_score': self.poi_data[poi_id]['score'],
                'fairness_score': self.poi_data[poi_id]['fairness'],
                'leg_cost_from_previous': leg_cost,
                'cumulative_cost': cumulative_cost
            })
        
        itinerary_df = pd.DataFrame(itinerary_data)
        
        print(f"[INFO] ✓ Itinerary built with {len(itinerary_df)} stops")
        return itinerary_df, cumulative_cost
    
    def display_results(self, itinerary_df, total_cost):
        """Display optimization results."""
        print("\n" + "=" * 80)
        print("GENETIC ALGORITHM OPTIMIZATION RESULTS")
        print("=" * 80)
        
        print(f"\n[RESULTS] Best Fitness Score: {self.best_fitness:.4f}")
        print(f"[RESULTS] Total Travel Cost: {total_cost:.2f}")
        print(f"[RESULTS] Average POI Score: {itinerary_df['final_group_score'].mean():.4f}")
        print(f"[RESULTS] Average Fairness: {itinerary_df['fairness_score'].mean():.4f}")
        
        print("\n" + "-" * 80)
        print(f"{'Stop':<6} {'POI ID':<20} {'Score':<8} {'Fairness':<10} "
              f"{'Leg Cost':<12} {'Cumulative':<12}")
        print("-" * 80)
        
        for _, row in itinerary_df.iterrows():
            leg_cost_str = f"{row['leg_cost_from_previous']:.2f}" if row['stop_number'] > 1 else "-"
            
            print(f"{row['stop_number']:<6} "
                  f"{str(row['poi_id']):<20} "
                  f"{row['final_group_score']:.4f}  "
                  f"{row['fairness_score']:.4f}    "
                  f"{leg_cost_str:<12} "
                  f"{row['cumulative_cost']:.2f}")
        
        print("-" * 80)
        
        # Evolution statistics
        print(f"\n[STATS] Evolution Summary:")
        print(f"  • Initial Best Fitness: {self.fitness_history[0]:.4f}")
        print(f"  • Final Best Fitness: {self.fitness_history[-1]:.4f}")
        print(f"  • Improvement: {((self.fitness_history[-1] - self.fitness_history[0]) / abs(self.fitness_history[0]) * 100):.2f}%")
    
    def save_itinerary(self, itinerary_df):
        """Save the optimized itinerary to CSV."""
        print("\n[STEP 7] Saving optimized itinerary...")
        
        self.data_dir.mkdir(parents=True, exist_ok=True)
        itinerary_df.to_csv(self.output_file, index=False)
        
        print(f"[SUCCESS] ✓ Itinerary saved to: {self.output_file}")
        print(f"[SUCCESS]   Rows: {len(itinerary_df)}")
        print(f"[SUCCESS]   Columns: {list(itinerary_df.columns)}")
    
    def run(self):
        """Execute the complete GA optimization pipeline."""
        try:
            # Load data
            self.load_data()
            
            # Detect columns
            self.detect_columns()
            
            # Select candidate pool
            self.select_candidate_pool()
            
            # Initialize population
            self.initialize_population()
            
            # Run evolution
            self.evolve()
            
            # Build final itinerary
            itinerary_df, total_cost = self.build_itinerary_from_chromosome(self.best_chromosome)
            
            # Display results
            self.display_results(itinerary_df, total_cost)
            
            # Save output
            self.save_itinerary(itinerary_df)
            
            print("\n" + "=" * 80)
            print("Pipeline Complete - GA-Optimized Itinerary Generated")
            print("=" * 80)
            
            return itinerary_df
            
        except Exception as e:
            print(f"\n[ERROR] Pipeline failed: {str(e)}")
            raise


def main():
    """Main execution function."""
    optimizer = GeneticItineraryOptimizer(
        candidate_pool_size=10,
        itinerary_size=5,
        population_size=40,
        generations=50,
        tournament_size=3,
        crossover_rate=0.8,
        mutation_rate=0.2,
        random_seed=42
    )
    itinerary = optimizer.run()


if __name__ == "__main__":
    main()
