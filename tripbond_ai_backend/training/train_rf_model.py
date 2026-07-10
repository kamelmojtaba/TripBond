"""
Random Forest Model Training for TripBond Recommender System
=============================================================
This script trains a Random Forest classifier to predict user-POI interactions
based on user preferences and POI features.

Author: TripBond AI Team
Date: 2026-02-19
"""

import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, 
    f1_score, roc_auc_score, classification_report, confusion_matrix
)
import joblib
import warnings
warnings.filterwarnings('ignore')


class TripBondModelTrainer:
    """Train and evaluate Random Forest model for POI recommendations."""
    
    def __init__(self, test_size=0.2, random_state=42):
        """
        Initialize the model trainer.
        
        Args:
            test_size: Proportion of dataset for testing
            random_state: Random seed for reproducibility
        """
        self.test_size = test_size
        self.random_state = random_state
        
        # Project paths
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.models_dir = self.project_root / "models"
        self.input_file = self.data_dir / "synthetic_interactions.csv"
        self.model_file = self.models_dir / "rf_model.pkl"
        
        # Data containers
        self.df = None
        self.X_train = None
        self.X_test = None
        self.y_train = None
        self.y_test = None
        self.model = None
        self.feature_names = None
    
    def load_data(self):
        """Load the interaction dataset."""
        print("=" * 70)
        print("TripBond Random Forest Model Training Pipeline")
        print("=" * 70)
        print("\n[INFO] Loading interaction dataset...")
        
        if not self.input_file.exists():
            raise FileNotFoundError(f"Dataset not found: {self.input_file}")
        
        self.df = pd.read_csv(self.input_file)
        print(f"[INFO] ✓ Dataset loaded successfully")
        print(f"[INFO] Shape: {self.df.shape}")
        print(f"[INFO] Columns: {len(self.df.columns)}")
    
    def prepare_features(self):
        """Separate features (X) and target (y)."""
        print("\n" + "=" * 70)
        print("Feature Preparation")
        print("=" * 70)
        
        # Identify columns to exclude
        exclude_cols = ['user_id', 'poi_id', 'liked']
        
        # Also exclude categorical text column (preferred_activity_type)
        categorical_cols = ['user_preferred_activity_type']
        exclude_cols.extend(categorical_cols)
        
        # Separate features and target
        feature_cols = [col for col in self.df.columns if col not in exclude_cols]
        self.feature_names = feature_cols
        
        X = self.df[feature_cols]
        y = self.df['liked']
        
        print(f"[INFO] Total features: {len(feature_cols)}")
        print(f"[INFO] Target variable: liked")
        print(f"[INFO] Target distribution:")
        print(f"  • Class 0 (Not Liked): {(y == 0).sum():>6,} ({(y == 0).sum() / len(y) * 100:>5.1f}%)")
        print(f"  • Class 1 (Liked)    : {(y == 1).sum():>6,} ({(y == 1).sum() / len(y) * 100:>5.1f}%)")
        
        return X, y
    
    def split_data(self, X, y):
        """Split data into training and testing sets."""
        print("\n" + "=" * 70)
        print("Data Splitting")
        print("=" * 70)
        
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, 
            test_size=self.test_size, 
            random_state=self.random_state,
            stratify=y  # Maintain class balance in splits
        )
        
        print(f"[INFO] Split ratio: {int((1-self.test_size)*100)}/{int(self.test_size*100)} (train/test)")
        print(f"[INFO] Training set  : {X_train.shape[0]:>6,} samples")
        print(f"[INFO] Testing set   : {X_test.shape[0]:>6,} samples")
        
        # Check class distribution in splits
        train_ratio = (y_train == 1).sum() / len(y_train) * 100
        test_ratio = (y_test == 1).sum() / len(y_test) * 100
        print(f"[INFO] Train positive class: {train_ratio:.1f}%")
        print(f"[INFO] Test positive class : {test_ratio:.1f}%")
        
        self.X_train = X_train
        self.X_test = X_test
        self.y_train = y_train
        self.y_test = y_test
    
    def train_model(self):
        """Train Random Forest classifier."""
        print("\n" + "=" * 70)
        print("Model Training")
        print("=" * 70)
        
        print("[INFO] Initializing Random Forest Classifier...")
        print("[INFO] Hyperparameters:")
        print("  • n_estimators   : 200")
        print("  • max_depth      : 15")
        print("  • class_weight   : balanced")
        print("  • random_state   : 42")
        
        self.model = RandomForestClassifier(
            n_estimators=200,
            max_depth=15,
            class_weight='balanced',
            random_state=42,
            n_jobs=-1,  # Use all CPU cores
            verbose=0
        )
        
        print("\n[INFO] Training model...")
        self.model.fit(self.X_train, self.y_train)
        print("[SUCCESS] ✓ Model training completed!")
    
    def evaluate_model(self):
        """Evaluate model performance on test set."""
        print("\n" + "=" * 70)
        print("Model Evaluation")
        print("=" * 70)
        
        print("[INFO] Generating predictions on test set...")
        
        # Predictions
        y_pred = self.model.predict(self.X_test)
        y_pred_proba = self.model.predict_proba(self.X_test)[:, 1]
        
        # Calculate metrics
        accuracy = accuracy_score(self.y_test, y_pred)
        precision = precision_score(self.y_test, y_pred, zero_division=0)
        recall = recall_score(self.y_test, y_pred, zero_division=0)
        f1 = f1_score(self.y_test, y_pred, zero_division=0)
        roc_auc = roc_auc_score(self.y_test, y_pred_proba)
        
        print("\n[RESULTS] Performance Metrics:")
        print(f"  • Accuracy   : {accuracy:.4f} ({accuracy * 100:.2f}%)")
        print(f"  • Precision  : {precision:.4f}")
        print(f"  • Recall     : {recall:.4f}")
        print(f"  • F1-Score   : {f1:.4f}")
        print(f"  • ROC-AUC    : {roc_auc:.4f}")
        
        # Confusion Matrix
        print("\n[RESULTS] Confusion Matrix:")
        cm = confusion_matrix(self.y_test, y_pred)
        print(f"  • True Negatives  (TN): {cm[0, 0]:>5,}")
        print(f"  • False Positives (FP): {cm[0, 1]:>5,}")
        print(f"  • False Negatives (FN): {cm[1, 0]:>5,}")
        print(f"  • True Positives  (TP): {cm[1, 1]:>5,}")
        
        # Classification Report
        print("\n[RESULTS] Classification Report:")
        print(classification_report(self.y_test, y_pred, 
                                   target_names=['Not Liked', 'Liked'],
                                   digits=4))
    
    def display_feature_importance(self, top_n=15):
        """Display top N most important features."""
        print("\n" + "=" * 70)
        print(f"Feature Importance (Top {top_n})")
        print("=" * 70)
        
        # Get feature importances
        importances = self.model.feature_importances_
        
        # Create DataFrame for better visualization
        feature_importance_df = pd.DataFrame({
            'feature': self.feature_names,
            'importance': importances
        }).sort_values('importance', ascending=False)
        
        # Display top N features
        print("\n[INFO] Most Important Features:")
        for idx, row in feature_importance_df.head(top_n).iterrows():
            bar_length = int(row['importance'] * 50)  # Scale to 50 chars
            bar = '█' * bar_length
            print(f"  {row['feature']:<35} : {row['importance']:.6f} {bar}")
        
        # Summary statistics
        top_n_sum = feature_importance_df.head(top_n)['importance'].sum()
        print(f"\n[INFO] Top {top_n} features account for {top_n_sum * 100:.1f}% of total importance")
    
    def save_model(self):
        """Save the trained model to disk."""
        print("\n" + "=" * 70)
        print("Saving Model")
        print("=" * 70)
        
        # Create models directory if it doesn't exist
        self.models_dir.mkdir(parents=True, exist_ok=True)
        
        # Save model
        print(f"[INFO] Saving model to: {self.model_file}")
        joblib.dump(self.model, self.model_file)
        
        # Verify file size
        file_size_mb = self.model_file.stat().st_size / (1024 * 1024)
        print(f"[SUCCESS] ✓ Model saved successfully!")
        print(f"[SUCCESS] File size: {file_size_mb:.2f} MB")
        
        # Save feature names for later use
        feature_names_file = self.models_dir / "feature_names.txt"
        with open(feature_names_file, 'w') as f:
            f.write('\n'.join(self.feature_names))
        print(f"[SUCCESS] ✓ Feature names saved to: {feature_names_file}")
    
    def run(self):
        """Execute the complete training pipeline."""
        # Load data
        self.load_data()
        
        # Prepare features
        X, y = self.prepare_features()
        
        # Split data
        self.split_data(X, y)
        
        # Train model
        self.train_model()
        
        # Evaluate model
        self.evaluate_model()
        
        # Display feature importance
        self.display_feature_importance(top_n=15)
        
        # Save model
        self.save_model()
        
        print("\n" + "=" * 70)
        print("Pipeline Complete!")
        print("=" * 70)
        print("\n[INFO] Next steps:")
        print("  1. Review model performance metrics")
        print("  2. Analyze feature importance")
        print("  3. Deploy model for predictions")
        print(f"  4. Model location: {self.model_file}")


def main():
    """Main execution function."""
    trainer = TripBondModelTrainer(test_size=0.2, random_state=42)
    trainer.run()


if __name__ == "__main__":
    main()
