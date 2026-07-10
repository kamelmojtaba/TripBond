"""
Synthetic Interaction Dataset Generator for TripBond
====================================================
This script generates synthetic user-POI interactions for training
the recommendation model.

Author: TripBond AI Team
Date: 2026-02-19
"""

import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.preprocessing import MinMaxScaler
import warnings
warnings.filterwarnings('ignore')


class SyntheticInteractionGenerator:
    """Generate synthetic user-POI interactions for recommendation training."""
    
    def __init__(self, interactions_per_user=40, like_threshold=0.5, random_seed=42):
        """
        Initialize the interaction generator.
        
        Args:
            interactions_per_user: Number of POI interactions per user
            like_threshold: Threshold for converting compatibility to binary like
            random_seed: Random seed for reproducibility
        """
        self.interactions_per_user = interactions_per_user
        self.like_threshold = like_threshold
        self.random_seed = random_seed
        np.random.seed(random_seed)
        
        # Project paths
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.users_file = self.data_dir / "synthetic_users.csv"
        self.pois_file = self.data_dir / "poi_features_ready.csv"
        self.output_file = self.data_dir / "synthetic_interactions.csv"
        
        # Data containers
        self.users_df = None
        self.pois_df = None
        self.interactions_df = None
    
    def load_data(self):
        """Load user and POI datasets."""
        print("=" * 70)
        print("TripBond Synthetic Interaction Generation Pipeline")
        print("=" * 70)
        print("\n[INFO] Loading datasets...")
        
        # Load users
        if not self.users_file.exists():
            raise FileNotFoundError(f"Users file not found: {self.users_file}")
        self.users_df = pd.read_csv(self.users_file)
        print(f"[INFO] ✓ Loaded users: {self.users_df.shape}")
        
        # Load POIs
        if not self.pois_file.exists():
            raise FileNotFoundError(f"POIs file not found: {self.pois_file}")
        self.pois_df = pd.read_csv(self.pois_file)
        
        # Add POI IDs based on index
        self.pois_df['poi_id'] = [f"POI_{str(i+1).zfill(3)}" for i in range(len(self.pois_df))]
        print(f"[INFO] ✓ Loaded POIs: {self.pois_df.shape}")
        
        print(f"[INFO] Total potential interactions: {len(self.users_df) * len(self.pois_df):,}")
    
    def extract_category_from_preferences(self, preferred_activity):
        """
        Extract category column name from user preference.
        
        Args:
            preferred_activity: User's preferred activity type
            
        Returns:
            str: Column name in POI dataset
        """
        return f"category_{preferred_activity}"
    
    def calculate_compatibility_score(self, user_row, poi_row):
        """
        Calculate compatibility score between user and POI.
        
        Scoring components:
        - Category match: 0.40 weight
        - Normalized rating: 0.30 weight
        - Popularity alignment: 0.20 weight
        - Activity intensity match: 0.10 weight
        
        Args:
            user_row: User data (Series)
            poi_row: POI data (Series)
            
        Returns:
            float: Compatibility score (0-1 range)
        """
        score = 0.0
        
        # 1. Category match (40% weight)
        preferred_category_col = self.extract_category_from_preferences(
            user_row['preferred_activity_type']
        )
        if preferred_category_col in poi_row.index:
            category_match = poi_row[preferred_category_col]
            score += 0.40 * category_match
        
        # 2. Normalized rating (30% weight)
        if 'normalized_rating' in poi_row.index:
            score += 0.30 * poi_row['normalized_rating']
        
        # 3. Popularity alignment (20% weight)
        # Users with higher openness prefer more popular places
        if 'popularity_score' in poi_row.index:
            # Normalize popularity score to 0-1 range for this calculation
            popularity_normalized = poi_row['popularity_score'] / 10.0  # Assuming max ~10
            popularity_weight = 0.5 + 0.5 * user_row['openness']  # 0.5 to 1.0 based on openness
            score += 0.20 * popularity_normalized * popularity_weight
        
        # 4. Activity intensity match (10% weight)
        if 'activity_intensity_score' in poi_row.index:
            # Normalize POI intensity (1-5) to 0-1 range
            poi_intensity_norm = (poi_row['activity_intensity_score'] - 1) / 4.0
            user_intensity = user_row['travel_intensity_score']
            
            # Similarity score (closer = better)
            intensity_similarity = 1 - abs(user_intensity - poi_intensity_norm)
            score += 0.10 * intensity_similarity
        
        # Add small random noise for realism
        noise = np.random.normal(0, 0.05)
        score = np.clip(score + noise, 0, 1)
        
        return score
    
    def generate_interactions(self):
        """Generate user-POI interactions with compatibility scores."""
        print("\n" + "=" * 70)
        print("Generating Interactions")
        print("=" * 70)
        
        interactions = []
        total_users = len(self.users_df)
        
        print(f"[INFO] Generating {self.interactions_per_user} interactions per user...")
        print(f"[INFO] Total interactions to generate: {total_users * self.interactions_per_user:,}")
        
        for idx, user_row in self.users_df.iterrows():
            if (idx + 1) % 50 == 0:
                print(f"[PROGRESS] Processed {idx + 1}/{total_users} users...")
            
            # Sample POIs for this user
            sampled_pois = self.pois_df.sample(
                n=min(self.interactions_per_user, len(self.pois_df)),
                random_state=self.random_seed + idx
            )
            
            for _, poi_row in sampled_pois.iterrows():
                # Calculate compatibility
                compatibility = self.calculate_compatibility_score(user_row, poi_row)
                
                # Convert to binary like
                liked = 1 if compatibility > self.like_threshold else 0
                
                # Create interaction record
                interaction = {
                    'user_id': user_row['user_id'],
                    'poi_id': poi_row['poi_id'],
                    'compatibility_score': compatibility  # Keep for analysis
                }
                
                # Add all user features (excluding user_id to avoid duplication)
                for col in self.users_df.columns:
                    if col != 'user_id':
                        interaction[f'user_{col}'] = user_row[col]
                
                # Add all POI features (excluding poi_id to avoid duplication)
                for col in self.pois_df.columns:
                    if col != 'poi_id':
                        interaction[f'poi_{col}'] = poi_row[col]
                
                # Add target label
                interaction['liked'] = liked
                
                interactions.append(interaction)
        
        print(f"[INFO] ✓ Generated {len(interactions):,} interactions")
        
        # Convert to DataFrame
        self.interactions_df = pd.DataFrame(interactions)
        return self.interactions_df
    
    def analyze_distribution(self):
        """Analyze the distribution of likes/dislikes."""
        print("\n" + "=" * 70)
        print("Interaction Statistics")
        print("=" * 70)
        
        # Like distribution
        likes = self.interactions_df['liked'].sum()
        dislikes = len(self.interactions_df) - likes
        like_ratio = likes / len(self.interactions_df)
        
        print(f"\n[STATS] Label Distribution:")
        print(f"  • Liked (1)      : {likes:>6,} ({like_ratio*100:>5.1f}%)")
        print(f"  • Not Liked (0)  : {dislikes:>6,} ({(1-like_ratio)*100:>5.1f}%)")
        
        # Compatibility score statistics
        print(f"\n[STATS] Compatibility Score:")
        print(f"  • Mean           : {self.interactions_df['compatibility_score'].mean():.3f}")
        print(f"  • Std            : {self.interactions_df['compatibility_score'].std():.3f}")
        print(f"  • Min            : {self.interactions_df['compatibility_score'].min():.3f}")
        print(f"  • Max            : {self.interactions_df['compatibility_score'].max():.3f}")
        print(f"  • Median         : {self.interactions_df['compatibility_score'].median():.3f}")
        
        # User and POI coverage
        unique_users = self.interactions_df['user_id'].nunique()
        unique_pois = self.interactions_df['poi_id'].nunique()
        print(f"\n[STATS] Coverage:")
        print(f"  • Unique Users   : {unique_users}")
        print(f"  • Unique POIs    : {unique_pois}")
        print(f"  • Avg interactions per user: {len(self.interactions_df) / unique_users:.1f}")
        print(f"  • Avg interactions per POI : {len(self.interactions_df) / unique_pois:.1f}")
    
    def prepare_final_dataset(self):
        """Prepare final dataset for model training."""
        print("\n" + "=" * 70)
        print("Preparing Final Dataset")
        print("=" * 70)
        
        # Reorder columns: identifiers, user features, POI features, target
        # Drop compatibility_score (only used for analysis)
        all_cols = list(self.interactions_df.columns)
        
        id_cols = ['user_id', 'poi_id']
        user_cols = sorted([col for col in all_cols if col.startswith('user_') and col not in id_cols])
        poi_cols = sorted([col for col in all_cols if col.startswith('poi_') and col not in id_cols])
        target_col = ['liked']
        
        column_order = id_cols + user_cols + poi_cols + target_col
        final_df = self.interactions_df[column_order]
        
        print(f"[INFO] Final dataset shape: {final_df.shape}")
        print(f"[INFO] Columns: {len(final_df.columns)}")
        print(f"  • Identifiers  : {len(id_cols)}")
        print(f"  • User features: {len(user_cols)}")
        print(f"  • POI features : {len(poi_cols)}")
        print(f"  • Target       : 1")
        
        return final_df
    
    def save_dataset(self, df):
        """Save the interaction dataset to CSV."""
        print("\n" + "=" * 70)
        print("Saving Dataset")
        print("=" * 70)
        
        self.data_dir.mkdir(parents=True, exist_ok=True)
        df.to_csv(self.output_file, index=False)
        
        print(f"[SUCCESS] ✓ Dataset saved to: {self.output_file}")
        print(f"[SUCCESS] Total interactions: {len(df):,}")
        print(f"[SUCCESS] Total features: {len(df.columns)}")
        
        # Show sample columns
        sample_cols = list(df.columns[:5]) + ['...'] + list(df.columns[-3:])
        print(f"[SUCCESS] Columns: {sample_cols}")
    
    def validate_dataset(self, df):
        """Validate the generated dataset."""
        print("\n" + "=" * 70)
        print("Dataset Validation")
        print("=" * 70)
        
        # Check for missing values
        missing = df.isnull().sum().sum()
        print(f"[CHECK] Missing values: {missing}")
        
        # Check target distribution
        if 'liked' in df.columns:
            target_dist = df['liked'].value_counts()
            print(f"[CHECK] Target class balance: {dict(target_dist)}")
        
        # Check duplicates
        duplicates = df.duplicated(subset=['user_id', 'poi_id']).sum()
        print(f"[CHECK] Duplicate (user, POI) pairs: {duplicates}")
        
        if missing == 0 and duplicates == 0:
            print("[SUCCESS] ✓ All validations passed!")
        else:
            if missing > 0:
                print(f"[WARNING] Found {missing} missing values")
            if duplicates > 0:
                print(f"[WARNING] Found {duplicates} duplicate interactions")
    
    def run(self):
        """Execute the complete interaction generation pipeline."""
        # Load data
        self.load_data()
        
        # Generate interactions
        self.generate_interactions()
        
        # Analyze
        self.analyze_distribution()
        
        # Prepare final dataset
        final_df = self.prepare_final_dataset()
        
        # Validate
        self.validate_dataset(final_df)
        
        # Save
        self.save_dataset(final_df)
        
        print("\n" + "=" * 70)
        print("Pipeline Complete!")
        print("=" * 70)
        
        return final_df


def main():
    """Main execution function."""
    generator = SyntheticInteractionGenerator(
        interactions_per_user=40,
        like_threshold=0.5,
        random_seed=42
    )
    df = generator.run()


if __name__ == "__main__":
    main()
