"""
Synthetic User Dataset Generator for TripBond
==============================================
This script generates synthetic user profiles with personality traits
and preferences for training the recommendation model.

Author: TripBond AI Team
Date: 2026-02-19
"""

import pandas as pd
import numpy as np
from pathlib import Path


class SyntheticUserGenerator:
    """Generate synthetic user profiles for recommendation system training."""
    
    def __init__(self, num_users=300, random_seed=42):
        """
        Initialize the synthetic user generator.
        
        Args:
            num_users: Number of synthetic users to generate
            random_seed: Random seed for reproducibility
        """
        self.num_users = num_users
        self.random_seed = random_seed
        np.random.seed(random_seed)
        
        # Project paths
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.output_file = self.data_dir / "synthetic_users.csv"
        
        # POI activity categories (based on feature engineering output)
        self.activity_categories = [
            'beach', 'shopping_mall', 'unesco_world_heritage_site',
            'museum', 'landmark', 'waterfront', 'natural_wonder',
            'natural_reserve', 'cultural_district', 'historic_site',
            'nature_park', 'historic_village', 'cultural_center',
            'historic_fort', 'heritage_village'
        ]
    
    def generate_personality_traits(self):
        """
        Generate Big Five personality traits with realistic distributions.
        
        Returns:
            dict: Dictionary with personality trait arrays
        """
        print("[INFO] Generating personality traits (Big Five)...")
        
        # Use beta distributions for more realistic personality scores
        # Most people cluster around medium values with tails at extremes
        traits = {
            'openness': np.random.beta(2, 2, self.num_users),
            'extraversion': np.random.beta(2, 2, self.num_users),
            'agreeableness': np.random.beta(2.5, 1.5, self.num_users),  # Slight positive skew
            'conscientiousness': np.random.beta(2.5, 2, self.num_users),
            'neuroticism': np.random.beta(2, 2.5, self.num_users)  # Slight negative skew
        }
        
        print(f"[INFO] ✓ Generated personality traits for {self.num_users} users")
        return traits
    
    def generate_budget_level(self):
        """
        Generate budget levels with realistic distribution.
        
        Returns:
            np.ndarray: Budget levels (0-1 normalized)
        """
        print("[INFO] Generating budget levels...")
        
        # Use log-normal distribution for budget (more realistic)
        # Then normalize to 0-1 range
        budget_raw = np.random.lognormal(mean=0, sigma=0.6, size=self.num_users)
        budget_normalized = (budget_raw - budget_raw.min()) / (budget_raw.max() - budget_raw.min())
        
        print(f"[INFO] ✓ Generated budget levels (mean: {budget_normalized.mean():.3f})")
        return budget_normalized
    
    def generate_preferred_activity(self):
        """
        Generate preferred activity types based on personality.
        
        Returns:
            np.ndarray: Array of preferred activity categories
        """
        print("[INFO] Generating preferred activity types...")
        
        # Random selection from available categories
        # Could be weighted by personality but keeping simple for diversity
        preferred_activities = np.random.choice(
            self.activity_categories,
            size=self.num_users,
            replace=True
        )
        
        # Count distribution
        unique, counts = np.unique(preferred_activities, return_counts=True)
        print(f"[INFO] ✓ Generated activity preferences ({len(unique)} unique types)")
        
        return preferred_activities
    
    def calculate_travel_intensity(self, traits):
        """
        Calculate travel intensity score from personality traits.
        
        High openness + high extraversion = high travel intensity
        High neuroticism = lower travel intensity
        
        Args:
            traits: Dictionary of personality trait arrays
            
        Returns:
            np.ndarray: Travel intensity scores (0-1 normalized)
        """
        print("[INFO] Calculating travel intensity scores...")
        
        # Weighted combination of personality traits
        intensity = (
            0.4 * traits['openness'] +
            0.3 * traits['extraversion'] +
            0.15 * traits['conscientiousness'] +
            0.05 * traits['agreeableness'] +
            0.1 * (1 - traits['neuroticism'])  # Inverse neuroticism
        )
        
        # Add some noise for realism
        noise = np.random.normal(0, 0.05, self.num_users)
        intensity = intensity + noise
        
        # Clip to [0, 1] range
        intensity = np.clip(intensity, 0, 1)
        
        print(f"[INFO] ✓ Calculated travel intensity (mean: {intensity.mean():.3f})")
        return intensity
    
    def create_user_ids(self):
        """
        Create unique user IDs.
        
        Returns:
            list: List of user IDs
        """
        return [f"USER_{str(i+1).zfill(6)}" for i in range(self.num_users)]
    
    def generate_dataset(self):
        """
        Generate the complete synthetic user dataset.
        
        Returns:
            pd.DataFrame: DataFrame with synthetic user profiles
        """
        print("\n" + "=" * 70)
        print("TripBond Synthetic User Generation Pipeline")
        print("=" * 70)
        print(f"[INFO] Generating {self.num_users} synthetic users...")
        print(f"[INFO] Random seed: {self.random_seed}")
        
        # Generate components
        user_ids = self.create_user_ids()
        traits = self.generate_personality_traits()
        budget = self.generate_budget_level()
        activities = self.generate_preferred_activity()
        intensity = self.calculate_travel_intensity(traits)
        
        # Construct DataFrame
        print("\n[INFO] Constructing user dataset...")
        df = pd.DataFrame({
            'user_id': user_ids,
            'openness': traits['openness'],
            'extraversion': traits['extraversion'],
            'agreeableness': traits['agreeableness'],
            'conscientiousness': traits['conscientiousness'],
            'neuroticism': traits['neuroticism'],
            'budget_level': budget,
            'preferred_activity_type': activities,
            'travel_intensity_score': intensity
        })
        
        print(f"[INFO] ✓ Dataset constructed. Shape: {df.shape}")
        return df
    
    def display_statistics(self, df):
        """
        Display dataset statistics.
        
        Args:
            df: User DataFrame
        """
        print("\n" + "=" * 70)
        print("Dataset Statistics")
        print("=" * 70)
        
        print("\n[STATS] Personality Traits (Mean ± Std):")
        for trait in ['openness', 'extraversion', 'agreeableness', 
                     'conscientiousness', 'neuroticism']:
            mean = df[trait].mean()
            std = df[trait].std()
            print(f"  • {trait.capitalize():<20} : {mean:.3f} ± {std:.3f}")
        
        print("\n[STATS] Other Features:")
        print(f"  • Budget Level (Mean)       : {df['budget_level'].mean():.3f}")
        print(f"  • Travel Intensity (Mean)   : {df['travel_intensity_score'].mean():.3f}")
        print(f"  • Unique Activity Types     : {df['preferred_activity_type'].nunique()}")
        
        print("\n[STATS] Top 5 Preferred Activities:")
        top_activities = df['preferred_activity_type'].value_counts().head(5)
        for activity, count in top_activities.items():
            percentage = (count / len(df)) * 100
            print(f"  • {activity:<30} : {count:>3} ({percentage:>5.1f}%)")
    
    def save_dataset(self, df):
        """
        Save the synthetic user dataset to CSV.
        
        Args:
            df: User DataFrame
        """
        print("\n" + "=" * 70)
        print("Saving Dataset")
        print("=" * 70)
        
        self.data_dir.mkdir(parents=True, exist_ok=True)
        df.to_csv(self.output_file, index=False)
        
        print(f"[SUCCESS] ✓ Dataset saved to: {self.output_file}")
        print(f"[SUCCESS] Total users: {len(df)}")
        print(f"[SUCCESS] Total features: {len(df.columns)}")
        print(f"[SUCCESS] Columns: {list(df.columns)}")
    
    def validate_dataset(self, df):
        """
        Validate the generated dataset.
        
        Args:
            df: User DataFrame
        """
        print("\n" + "=" * 70)
        print("Dataset Validation")
        print("=" * 70)
        
        # Check for missing values
        missing = df.isnull().sum().sum()
        print(f"[CHECK] Missing values: {missing}")
        
        # Check value ranges
        numeric_cols = ['openness', 'extraversion', 'agreeableness', 
                       'conscientiousness', 'neuroticism', 'budget_level', 
                       'travel_intensity_score']
        
        all_valid = True
        for col in numeric_cols:
            min_val = df[col].min()
            max_val = df[col].max()
            if min_val < 0 or max_val > 1:
                print(f"[ERROR] {col}: Values out of range [{min_val:.3f}, {max_val:.3f}]")
                all_valid = False
        
        if all_valid and missing == 0:
            print("[SUCCESS] ✓ All validations passed!")
        else:
            print("[WARNING] Some validation checks failed")
    
    def run(self):
        """Execute the complete user generation pipeline."""
        # Generate dataset
        df = self.generate_dataset()
        
        # Validate
        self.validate_dataset(df)
        
        # Display statistics
        self.display_statistics(df)
        
        # Save
        self.save_dataset(df)
        
        print("\n" + "=" * 70)
        print("Pipeline Complete!")
        print("=" * 70)
        
        return df


def main():
    """Main execution function."""
    generator = SyntheticUserGenerator(num_users=300, random_seed=42)
    df = generator.run()


if __name__ == "__main__":
    main()
