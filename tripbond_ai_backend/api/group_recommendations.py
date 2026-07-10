"""
Group POI Recommendation System for TripBond
=============================================
This script generates group recommendations by aggregating individual
user preferences using multiple scoring strategies.

Author: TripBond AI Team
Date: 2026-02-19
"""

import pandas as pd
import numpy as np
from pathlib import Path
import joblib
import warnings
warnings.filterwarnings('ignore')


class TripBondGroupRecommender:
    """Generate group POI recommendations using trained model."""
    
    def __init__(self, user_ids=None):
        """
        Initialize the group recommender system.
        
        Args:
            user_ids: List of user IDs for group recommendations
        """
        self.user_ids = user_ids
        
        # Project paths
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.models_dir = self.project_root / "models"
        
        # File paths
        self.model_file = self.models_dir / "rf_model.pkl"
        self.feature_names_file = self.models_dir / "feature_names.txt"
        self.users_file = self.data_dir / "synthetic_users.csv"
        self.pois_file = self.data_dir / "poi_features_ready.csv"
        self.output_file = self.data_dir / "top_pois_for_group.csv"
        
        # Data containers
        self.model = None
        self.feature_names = None
        self.users_df = None
        self.pois_df = None
        self.group_users = []
    
    def load_model(self):
        """Load the trained Random Forest model."""
        print("=" * 70)
        print("TripBond Group POI Recommendation System")
        print("=" * 70)
        print("\n[INFO] Loading trained model...")
        
        if not self.model_file.exists():
            raise FileNotFoundError(f"Model not found: {self.model_file}")
        
        self.model = joblib.load(self.model_file)
        print(f"[SUCCESS] ✓ Model loaded successfully")
        print(f"[INFO] Model type: {type(self.model).__name__}")
    
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
    
    def select_group_users(self):
        """Select users for group recommendations."""
        print("\n" + "=" * 70)
        print("Group User Selection")
        print("=" * 70)
        
        if self.user_ids is None or len(self.user_ids) == 0:
            # Use first 3 users as demo
            self.group_users = self.users_df.head(3)['user_id'].tolist()
            print(f"[INFO] No user_ids provided, using first 3 users as demo")
        else:
            # Find specified users
            found_users = []
            for uid in self.user_ids:
                user_match = self.users_df[self.users_df['user_id'] == uid]
                if not user_match.empty:
                    found_users.append(uid)
                else:
                    print(f"[WARNING] User '{uid}' not found, skipping")
            
            if len(found_users) == 0:
                print(f"[WARNING] No valid users found, using first 3 users instead")
                self.group_users = self.users_df.head(3)['user_id'].tolist()
            else:
                self.group_users = found_users
                print(f"[INFO] ✓ Found {len(found_users)} valid users")
        
        # Display group members
        print(f"\n[INFO] Group Members ({len(self.group_users)} users):")
        for i, uid in enumerate(self.group_users, 1):
            user_data = self.users_df[self.users_df['user_id'] == uid].iloc[0]
            print(f"  {i}. {uid}")
            print(f"     • Preferred Activity: {user_data['preferred_activity_type']}")
            print(f"     • Travel Intensity  : {user_data['travel_intensity_score']:.3f}")
            print(f"     • Openness          : {user_data['openness']:.3f}")
    
    def create_feature_matrix_for_user(self, user_id):
        """
        Create feature matrix for one user with all POIs.
        
        Args:
            user_id: User ID to create features for
            
        Returns:
            pd.DataFrame: Aligned feature matrix
        """
        user_row = self.users_df[self.users_df['user_id'] == user_id].iloc[0]
        
        # Prepare user features (exclude user_id and categorical preferred_activity_type)
        user_feature_cols = [col for col in self.users_df.columns 
                            if col not in ['user_id', 'preferred_activity_type']]
        
        # Create repeated user features for each POI
        user_features_repeated = pd.DataFrame(
            [user_row[user_feature_cols].values] * len(self.pois_df),
            columns=[f'user_{col}' for col in user_feature_cols]
        )
        
        # Prepare POI features (exclude poi_id if present)
        poi_feature_cols = [col for col in self.pois_df.columns if col != 'poi_id']
        poi_features = self.pois_df[poi_feature_cols].copy()
        poi_features.columns = [f'poi_{col}' for col in poi_feature_cols]
        
        # Combine user and POI features
        combined_features = pd.concat([
            user_features_repeated.reset_index(drop=True), 
            poi_features.reset_index(drop=True)
        ], axis=1)
        
        # Align with model's expected features
        aligned_features = pd.DataFrame(
            0, index=range(len(self.pois_df)), 
            columns=self.feature_names
        )
        
        # Fill in available features
        for col in self.feature_names:
            if col in combined_features.columns:
                aligned_features[col] = combined_features[col].values
        
        return aligned_features
    
    def predict_user_scores(self, user_id):
        """
        Predict POI scores for a single user.
        
        Args:
            user_id: User ID to generate predictions for
            
        Returns:
            pd.DataFrame: DataFrame with columns [poi_id, user_id, prob]
        """
        # Create feature matrix
        feature_matrix = self.create_feature_matrix_for_user(user_id)
        
        # Get probability predictions for class 1 (liked)
        probabilities = self.model.predict_proba(feature_matrix)[:, 1]
        
        # Create results DataFrame
        results = pd.DataFrame({
            'poi_id': self.pois_df['poi_id'],
            'user_id': user_id,
            'prob': probabilities
        })
        
        return results
    
    def build_probability_matrix(self):
        """
        Build POI × Users probability matrix.
        
        Returns:
            pd.DataFrame: Probability matrix with POIs as rows, users as columns
        """
        print("\n" + "=" * 70)
        print("Building Probability Matrix")
        print("=" * 70)
        print(f"[INFO] Predicting for {len(self.group_users)} users × {len(self.pois_df)} POIs...")
        
        # Collect predictions for all users
        all_predictions = []
        for i, user_id in enumerate(self.group_users, 1):
            print(f"[PROGRESS] Processing user {i}/{len(self.group_users)}: {user_id}")
            user_scores = self.predict_user_scores(user_id)
            all_predictions.append(user_scores)
        
        # Combine predictions
        combined = pd.concat(all_predictions, ignore_index=True)
        
        # Pivot to create POI × Users matrix
        prob_matrix = combined.pivot(index='poi_id', columns='user_id', values='prob')
        
        print(f"[SUCCESS] ✓ Probability matrix built: {prob_matrix.shape}")
        print(f"[INFO] Probability range: [{prob_matrix.min().min():.4f}, {prob_matrix.max().max():.4f}]")
        
        return prob_matrix
    
    def compute_group_scores(self, prob_matrix):
        """
        Compute group aggregation scores for each POI.
        
        Args:
            prob_matrix: POI × Users probability matrix
            
        Returns:
            pd.DataFrame: Group scores for each POI
        """
        print("\n" + "=" * 70)
        print("Computing Group Aggregation Scores")
        print("=" * 70)
        
        # Calculate aggregation metrics
        avg_score = prob_matrix.mean(axis=1)
        min_score = prob_matrix.min(axis=1)  # Least misery
        std_score = prob_matrix.std(axis=1)
        
        # Fairness score: 1 - normalized std (higher = more fair)
        fairness_score = 1 - std_score
        fairness_score = fairness_score.clip(0, 1)
        
        # Final group score: weighted combination
        final_group_score = (
            0.5 * avg_score +
            0.3 * min_score +
            0.2 * fairness_score
        )
        
        # Create results DataFrame
        group_scores = pd.DataFrame({
            'poi_id': prob_matrix.index,
            'avg_score': avg_score.values,
            'min_score': min_score.values,
            'fairness_score': fairness_score.values,
            'final_group_score': final_group_score.values
        })
        
        print(f"[SUCCESS] ✓ Group scores computed")
        print(f"\n[STATS] Score Statistics:")
        print(f"  • Average Score     : {avg_score.mean():.4f} (±{avg_score.std():.4f})")
        print(f"  • Min Score (LM)    : {min_score.mean():.4f} (±{min_score.std():.4f})")
        print(f"  • Fairness Score    : {fairness_score.mean():.4f} (±{fairness_score.std():.4f})")
        print(f"  • Final Group Score : {final_group_score.mean():.4f} (±{final_group_score.std():.4f})")
        
        return group_scores
    
    def get_top_recommendations(self, group_scores, top_n=15):
        """
        Get top N group recommendations with metadata.
        
        Args:
            group_scores: DataFrame with group scores
            top_n: Number of top recommendations to return
            
        Returns:
            pd.DataFrame: Top N recommendations with metadata
        """
        print("\n" + "=" * 70)
        print(f"Top {top_n} Group Recommendations")
        print("=" * 70)
        
        # Sort by final_group_score
        sorted_scores = group_scores.sort_values('final_group_score', ascending=False)
        
        # Get top N
        top_recommendations = sorted_scores.head(top_n).copy()
        
        # Add POI metadata
        poi_metadata = self.pois_df.set_index('poi_id')
        
        for poi_id in top_recommendations['poi_id']:
            idx = top_recommendations[top_recommendations['poi_id'] == poi_id].index[0]
            
            # Add latitude/longitude
            if 'latitude' in poi_metadata.columns:
                top_recommendations.loc[idx, 'poi_latitude'] = poi_metadata.loc[poi_id, 'latitude']
            if 'longitude' in poi_metadata.columns:
                top_recommendations.loc[idx, 'poi_longitude'] = poi_metadata.loc[poi_id, 'longitude']
            
            # Add rating and popularity
            if 'normalized_rating' in poi_metadata.columns:
                top_recommendations.loc[idx, 'poi_normalized_rating'] = poi_metadata.loc[poi_id, 'normalized_rating']
            if 'popularity_score' in poi_metadata.columns:
                top_recommendations.loc[idx, 'poi_popularity_score'] = poi_metadata.loc[poi_id, 'popularity_score']
            
            # Extract category from one-hot encoded columns
            category_cols = [col for col in poi_metadata.columns if col.startswith('category_')]
            category = 'unknown'
            for cat_col in category_cols:
                if poi_metadata.loc[poi_id, cat_col] == 1:
                    category = cat_col.replace('category_', '')
                    break
            top_recommendations.loc[idx, 'poi_category'] = category
        
        # Reset index
        top_recommendations = top_recommendations.reset_index(drop=True)
        
        print(f"[SUCCESS] ✓ Generated top {top_n} group recommendations")
        
        return top_recommendations
    
    def print_top_results(self, recommendations, top_n=10):
        """
        Print top N results to console.
        
        Args:
            recommendations: DataFrame with recommendations
            top_n: Number of results to print
        """
        print(f"\n[RESULTS] Top {min(top_n, len(recommendations))} POIs for Group:")
        print("-" * 70)
        
        for idx, row in recommendations.head(top_n).iterrows():
            rank = idx + 1
            poi_id = row['poi_id']
            final_score = row['final_group_score']
            avg_score = row['avg_score']
            min_score = row['min_score']
            fairness = row['fairness_score']
            category = row.get('poi_category', 'N/A')
            rating = row.get('poi_normalized_rating', 0)
            
            print(f"\n{rank:2}. {poi_id}")
            print(f"    Final Score : {final_score:.4f}")
            print(f"    Avg Score   : {avg_score:.4f} | Min Score: {min_score:.4f} | Fairness: {fairness:.4f}")
            print(f"    Category    : {category:<25} | Rating: {rating:.3f}")
    
    def save_recommendations(self, recommendations):
        """
        Save group recommendations to CSV.
        
        Args:
            recommendations: DataFrame with recommendations
        """
        print("\n" + "=" * 70)
        print("Saving Recommendations")
        print("=" * 70)
        
        self.data_dir.mkdir(parents=True, exist_ok=True)
        recommendations.to_csv(self.output_file, index=False)
        
        print(f"[SUCCESS] ✓ Recommendations saved to: {self.output_file}")
        print(f"[SUCCESS] Total recommendations: {len(recommendations)}")
        print(f"[SUCCESS] Group size: {len(self.group_users)} users")
    
    def run(self, top_n=15):
        """
        Execute the complete group recommendation pipeline.
        
        Args:
            top_n: Number of top recommendations to generate
        """
        # Load model and data
        self.load_model()
        self.load_feature_names()
        self.load_data()
        
        # Select group users
        self.select_group_users()
        
        # Build probability matrix
        prob_matrix = self.build_probability_matrix()
        
        # Compute group scores
        group_scores = self.compute_group_scores(prob_matrix)
        
        # Get top recommendations
        recommendations = self.get_top_recommendations(group_scores, top_n=top_n)
        
        # Print results
        self.print_top_results(recommendations, top_n=10)
        
        # Save results
        self.save_recommendations(recommendations)
        
        print("\n" + "=" * 70)
        print("Group Recommendation Pipeline Complete!")
        print("=" * 70)
        print(f"\n[INFO] Group: {', '.join(self.group_users)}")
        print(f"[INFO] Top {top_n} POIs saved to: {self.output_file}")
        
        return recommendations


def main():
    """Main execution function."""
    # Option 1: Use first 3 users as demo (default)
    recommender = TripBondGroupRecommender()
    
    # Option 2: Specify user IDs (uncomment to use)
    # recommender = TripBondGroupRecommender(user_ids=["USER_000001", "USER_000002", "USER_000003"])
    
    # Generate top 15 group recommendations
    recommendations = recommender.run(top_n=15)


if __name__ == "__main__":
    main()
