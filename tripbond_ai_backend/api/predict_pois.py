"""
POI Recommendation Inference Script for TripBond
=================================================
This script loads the trained Random Forest model and generates
personalized POI recommendations for a given user.

Author: TripBond AI Team
Date: 2026-02-19
"""

import pandas as pd
import numpy as np
from pathlib import Path
import joblib
import warnings
warnings.filterwarnings('ignore')


class TripBondRecommender:
    """Generate personalized POI recommendations using trained model."""
    
    def __init__(self, user_id=None):
        """
        Initialize the recommender system.
        
        Args:
            user_id: Target user ID for recommendations (default: use first user)
        """
        self.user_id = user_id
        
        # Project paths
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.models_dir = self.project_root / "models"
        
        # File paths
        self.model_file = self.models_dir / "rf_model.pkl"
        self.feature_names_file = self.models_dir / "feature_names.txt"
        self.users_file = self.data_dir / "synthetic_users.csv"
        self.pois_file = self.data_dir / "poi_features_ready.csv"
        self.output_file = self.data_dir / "top_pois_for_user.csv"
        
        # Data containers
        self.model = None
        self.feature_names = None
        self.users_df = None
        self.pois_df = None
        self.target_user = None
    
    def load_model(self):
        """Load the trained Random Forest model."""
        print("=" * 70)
        print("TripBond POI Recommendation System")
        print("=" * 70)
        print("\n[INFO] Loading trained model...")
        
        if not self.model_file.exists():
            raise FileNotFoundError(f"Model not found: {self.model_file}")
        
        self.model = joblib.load(self.model_file)
        file_size_mb = self.model_file.stat().st_size / (1024 * 1024)
        
        print(f"[SUCCESS] ✓ Model loaded successfully")
        print(f"[INFO] Model type: {type(self.model).__name__}")
        print(f"[INFO] Model size: {file_size_mb:.2f} MB")
        print(f"[INFO] Number of trees: {self.model.n_estimators}")
    
    def load_feature_names(self):
        """Load feature names to ensure correct column order."""
        print("\n[INFO] Loading feature names...")
        
        if not self.feature_names_file.exists():
            raise FileNotFoundError(f"Feature names not found: {self.feature_names_file}")
        
        with open(self.feature_names_file, 'r') as f:
            self.feature_names = [line.strip() for line in f.readlines()]
        
        print(f"[SUCCESS] ✓ Loaded {len(self.feature_names)} feature names")
    
    def load_data(self):
        """Load user and POI datasets."""
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
        
        # Add POI IDs if not present
        if 'poi_id' not in self.pois_df.columns:
            self.pois_df['poi_id'] = [f"POI_{str(i+1).zfill(3)}" for i in range(len(self.pois_df))]
        
        print(f"[INFO] ✓ Loaded POIs: {self.pois_df.shape}")
    
    def select_target_user(self):
        """Select the target user for recommendations."""
        print("\n" + "=" * 70)
        print("User Selection")
        print("=" * 70)
        
        if self.user_id is None:
            # Use first user
            self.target_user = self.users_df.iloc[0]
            self.user_id = self.target_user['user_id']
            print(f"[INFO] No user_id provided, using first user: {self.user_id}")
        else:
            # Find specified user
            user_match = self.users_df[self.users_df['user_id'] == self.user_id]
            if user_match.empty:
                print(f"[WARNING] User '{self.user_id}' not found, using first user instead")
                self.target_user = self.users_df.iloc[0]
                self.user_id = self.target_user['user_id']
            else:
                self.target_user = user_match.iloc[0]
                print(f"[INFO] ✓ Found user: {self.user_id}")
        
        # Display user profile
        print(f"\n[INFO] User Profile:")
        print(f"  • User ID              : {self.target_user['user_id']}")
        print(f"  • Openness             : {self.target_user['openness']:.3f}")
        print(f"  • Extraversion         : {self.target_user['extraversion']:.3f}")
        print(f"  • Agreeableness        : {self.target_user['agreeableness']:.3f}")
        print(f"  • Conscientiousness    : {self.target_user['conscientiousness']:.3f}")
        print(f"  • Neuroticism          : {self.target_user['neuroticism']:.3f}")
        print(f"  • Budget Level         : {self.target_user['budget_level']:.3f}")
        print(f"  • Preferred Activity   : {self.target_user['preferred_activity_type']}")
        print(f"  • Travel Intensity     : {self.target_user['travel_intensity_score']:.3f}")
    
    def create_feature_matrix(self):
        """
        Create feature matrix by combining user features with all POI features.
        
        Returns:
            pd.DataFrame: Feature matrix aligned with model's expected features
        """
        print("\n" + "=" * 70)
        print("Feature Matrix Construction")
        print("=" * 70)
        print(f"[INFO] Creating feature matrix for {len(self.pois_df)} POIs...")
        
        # Prepare user features (exclude user_id and categorical preferred_activity_type)
        user_feature_cols = [col for col in self.users_df.columns 
                            if col not in ['user_id', 'preferred_activity_type']]
        
        # Create repeated user features for each POI
        user_features_repeated = pd.DataFrame([self.target_user[user_feature_cols].values] * len(self.pois_df),
                                              columns=[f'user_{col}' for col in user_feature_cols])
        
        # Prepare POI features (exclude poi_id if present)
        poi_feature_cols = [col for col in self.pois_df.columns if col != 'poi_id']
        poi_features = self.pois_df[poi_feature_cols].copy()
        poi_features.columns = [f'poi_{col}' for col in poi_feature_cols]
        
        # Combine user and POI features
        combined_features = pd.concat([user_features_repeated.reset_index(drop=True), 
                                       poi_features.reset_index(drop=True)], axis=1)
        
        print(f"[INFO] Combined feature matrix shape: {combined_features.shape}")
        
        # Align with model's expected features
        print(f"[INFO] Aligning to {len(self.feature_names)} model features...")
        aligned_features = pd.DataFrame(0, index=range(len(self.pois_df)), 
                                       columns=self.feature_names)
        
        # Fill in available features
        for col in self.feature_names:
            if col in combined_features.columns:
                aligned_features[col] = combined_features[col].values
        
        print(f"[SUCCESS] ✓ Feature matrix aligned: {aligned_features.shape}")
        
        return aligned_features
    
    def generate_predictions(self, feature_matrix):
        """
        Generate predictions for all POIs.
        
        Args:
            feature_matrix: Aligned feature matrix
            
        Returns:
            np.ndarray: Predicted probabilities for class 1 (liked)
        """
        print("\n" + "=" * 70)
        print("Generating Predictions")
        print("=" * 70)
        print(f"[INFO] Predicting for {len(feature_matrix)} POIs...")
        
        # Get probability predictions for class 1 (liked)
        probabilities = self.model.predict_proba(feature_matrix)[:, 1]
        
        print(f"[SUCCESS] ✓ Predictions generated")
        print(f"[INFO] Probability range: [{probabilities.min():.4f}, {probabilities.max():.4f}]")
        print(f"[INFO] Mean probability: {probabilities.mean():.4f}")
        
        return probabilities
    
    def get_top_recommendations(self, probabilities, top_n=15):
        """
        Get top N POI recommendations.
        
        Args:
            probabilities: Predicted probabilities
            top_n: Number of top recommendations to return
            
        Returns:
            pd.DataFrame: Top N recommendations with metadata
        """
        print("\n" + "=" * 70)
        print(f"Top {top_n} Recommendations")
        print("=" * 70)
        
        # Create results DataFrame
        results = pd.DataFrame({
            'poi_id': self.pois_df['poi_id'],
            'predicted_like_prob': probabilities
        })
        
        # Add POI metadata
        if 'latitude' in self.pois_df.columns:
            results['poi_latitude'] = self.pois_df['latitude'].values
        if 'longitude' in self.pois_df.columns:
            results['poi_longitude'] = self.pois_df['longitude'].values
        if 'normalized_rating' in self.pois_df.columns:
            results['poi_normalized_rating'] = self.pois_df['normalized_rating'].values
        if 'popularity_score' in self.pois_df.columns:
            results['poi_popularity_score'] = self.pois_df['popularity_score'].values
        
        # Extract category information from one-hot encoded columns
        category_cols = [col for col in self.pois_df.columns if col.startswith('category_')]
        if category_cols:
            def get_category(row_idx):
                for cat_col in category_cols:
                    if self.pois_df.iloc[row_idx][cat_col] == 1:
                        return cat_col.replace('category_', '')
                return 'unknown'
            
            results['poi_category'] = [get_category(i) for i in range(len(self.pois_df))]
        
        # Sort by probability (descending) and get top N
        top_recommendations = results.sort_values('predicted_like_prob', ascending=False).head(top_n)
        top_recommendations = top_recommendations.reset_index(drop=True)
        top_recommendations.index = range(1, len(top_recommendations) + 1)
        
        # Display summary
        print(f"[SUCCESS] ✓ Generated top {top_n} recommendations")
        print(f"\n[RESULTS] Top 5 POIs:")
        for idx, row in top_recommendations.head(5).iterrows():
            category = row.get('poi_category', 'N/A')
            rating = row.get('poi_normalized_rating', 0)
            print(f"  {idx}. {row['poi_id']:<10} | Prob: {row['predicted_like_prob']:.4f} | "
                  f"Category: {category:<20} | Rating: {rating:.3f}")
        
        return top_recommendations
    
    def save_recommendations(self, recommendations):
        """
        Save recommendations to CSV.
        
        Args:
            recommendations: DataFrame with top recommendations
        """
        print("\n" + "=" * 70)
        print("Saving Recommendations")
        print("=" * 70)
        
        self.data_dir.mkdir(parents=True, exist_ok=True)
        recommendations.to_csv(self.output_file, index=False)
        
        print(f"[SUCCESS] ✓ Recommendations saved to: {self.output_file}")
        print(f"[SUCCESS] Total recommendations: {len(recommendations)}")
        print(f"[SUCCESS] Columns: {list(recommendations.columns)}")
    
    def run(self, top_n=15):
        """
        Execute the complete recommendation pipeline.
        
        Args:
            top_n: Number of top recommendations to generate
        """
        # Load model and data
        self.load_model()
        self.load_feature_names()
        self.load_data()
        
        # Select target user
        self.select_target_user()
        
        # Create feature matrix
        feature_matrix = self.create_feature_matrix()
        
        # Generate predictions
        probabilities = self.generate_predictions(feature_matrix)
        
        # Get top recommendations
        recommendations = self.get_top_recommendations(probabilities, top_n=top_n)
        
        # Save results
        self.save_recommendations(recommendations)
        
        print("\n" + "=" * 70)
        print("Recommendation Pipeline Complete!")
        print("=" * 70)
        print(f"\n[INFO] User: {self.user_id}")
        print(f"[INFO] Top {top_n} POIs saved to: {self.output_file}")
        
        return recommendations


def main():
    """Main execution function."""
    # Option 1: Use first user (default)
    recommender = TripBondRecommender()
    
    # Option 2: Specify a user ID (uncomment to use)
    # recommender = TripBondRecommender(user_id="USER_000001")
    
    # Generate top 15 recommendations
    recommendations = recommender.run(top_n=15)


if __name__ == "__main__":
    main()
