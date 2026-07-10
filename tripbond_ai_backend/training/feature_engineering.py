"""
Feature Engineering Script for TripBond POI Dataset
===================================================
This script performs feature engineering on the Point of Interest (POI) dataset
to prepare it for machine learning model training.

Author: TripBond AI Team
Date: 2026-02-19
"""

import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.preprocessing import MinMaxScaler
import warnings
warnings.filterwarnings('ignore')


class POIFeatureEngineer:
    """Feature engineering pipeline for POI dataset."""
    
    def __init__(self):
        """Initialize the feature engineer with project paths."""
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        self.input_file = self.data_dir / "final_integrated_poi_dataset.csv"
        self.output_file = self.data_dir / "poi_features_ready.csv"
        
        # Column detection patterns
        self.column_patterns = {
            'category': ['category', 'type', 'poi_type', 'attraction_type'],
            'rating': ['rating', 'score', 'stars', 'review_score'],
            'review_count': ['review_count', 'reviews', 'num_reviews', 'review_num'],
            'price': ['price', 'price_level', 'cost', 'pricing'],
            'latitude': ['latitude', 'lat', 'y_coord'],
            'longitude': ['longitude', 'lon', 'lng', 'long', 'x_coord']
        }
        
        # Indoor/Outdoor category mapping
        self.indoor_categories = {
            'museum', 'gallery', 'theater', 'cinema', 'mall', 'shopping',
            'center', 'palace', 'castle', 'fort', 'cultural center',
            'indoor', 'exhibition', 'library', 'aquarium'
        }
        
        # Activity intensity mapping (1-5 scale)
        self.intensity_mapping = {
            'low': ['museum', 'gallery', 'palace', 'library', 'cultural', 'historic site'],
            'medium': ['park', 'beach', 'waterfront', 'garden', 'district', 'village'],
            'high': ['adventure', 'climbing', 'hiking', 'sports', 'dive', 'surf']
        }
    
    def detect_column(self, df, column_type):
        """
        Dynamically detect column name based on patterns.
        
        Args:
            df: DataFrame to search
            column_type: Type of column to detect
            
        Returns:
            str: Detected column name or None
        """
        patterns = self.column_patterns.get(column_type, [])
        df_columns_lower = [col.lower() for col in df.columns]
        
        for pattern in patterns:
            for i, col_lower in enumerate(df_columns_lower):
                if pattern in col_lower:
                    return df.columns[i]
        return None
    
    def load_data(self):
        """Load the POI dataset from CSV."""
        print(f"[INFO] Loading dataset from: {self.input_file}")
        
        if not self.input_file.exists():
            raise FileNotFoundError(f"Dataset not found at {self.input_file}")
        
        df = pd.read_csv(self.input_file)
        print(f"[INFO] Dataset loaded successfully. Shape: {df.shape}")
        return df
    
    def detect_columns(self, df):
        """Detect all required columns dynamically."""
        detected = {}
        
        for col_type in ['category', 'rating', 'review_count', 'price', 'latitude', 'longitude']:
            col_name = self.detect_column(df, col_type)
            detected[col_type] = col_name
            status = "✓" if col_name else "✗"
            print(f"[INFO] {status} {col_type.upper()}: {col_name if col_name else 'Not found'}")
        
        return detected
    
    def clean_data(self, df, columns):
        """
        Clean missing values and invalid data.
        
        Args:
            df: Input DataFrame
            columns: Dictionary of detected column names
            
        Returns:
            pd.DataFrame: Cleaned DataFrame
        """
        print("\n[INFO] Cleaning data...")
        df_clean = df.copy()
        initial_rows = len(df_clean)
        
        # Handle rating column
        if columns['rating']:
            df_clean[columns['rating']] = pd.to_numeric(
                df_clean[columns['rating']], errors='coerce'
            )
            df_clean[columns['rating']].fillna(
                df_clean[columns['rating']].median(), inplace=True
            )
            # Ensure ratings are in valid range
            df_clean[columns['rating']] = df_clean[columns['rating']].clip(0, 5)
        
        # Handle review_count column
        if columns['review_count']:
            df_clean[columns['review_count']] = pd.to_numeric(
                df_clean[columns['review_count']], errors='coerce'
            )
            df_clean[columns['review_count']].fillna(0, inplace=True)
            df_clean[columns['review_count']] = df_clean[columns['review_count']].clip(lower=0)
        
        # Handle price column if exists
        if columns['price']:
            df_clean[columns['price']] = pd.to_numeric(
                df_clean[columns['price']], errors='coerce'
            )
            df_clean[columns['price']].fillna(
                df_clean[columns['price']].median(), inplace=True
            )
        
        # Handle category column
        if columns['category']:
            df_clean[columns['category']].fillna('Unknown', inplace=True)
        
        # Remove rows with missing coordinates
        if columns['latitude'] and columns['longitude']:
            df_clean = df_clean.dropna(subset=[columns['latitude'], columns['longitude']])
        
        final_rows = len(df_clean)
        print(f"[INFO] Data cleaned. Rows: {initial_rows} → {final_rows} ({initial_rows - final_rows} removed)")
        
        return df_clean
    
    def create_normalized_rating(self, df, rating_col):
        """Create normalized rating feature (0-1 scale)."""
        if rating_col and rating_col in df.columns:
            scaler = MinMaxScaler()
            df['normalized_rating'] = scaler.fit_transform(df[[rating_col]])
            print("[INFO] ✓ Created: normalized_rating")
        return df
    
    def create_popularity_score(self, df, review_col):
        """Create popularity score using log transformation."""
        if review_col and review_col in df.columns:
            df['popularity_score'] = np.log1p(df[review_col])
            print("[INFO] ✓ Created: popularity_score")
        return df
    
    def create_normalized_price(self, df, price_col):
        """Create normalized price feature if price exists."""
        if price_col and price_col in df.columns:
            scaler = MinMaxScaler()
            df['normalized_price'] = scaler.fit_transform(df[[price_col]])
            print("[INFO] ✓ Created: normalized_price")
        else:
            print("[INFO] ⊗ Skipped: normalized_price (no price column)")
        return df
    
    def create_category_encoding(self, df, category_col):
        """Create one-hot encoded category features."""
        if category_col and category_col in df.columns:
            # Clean category names
            df[category_col] = df[category_col].str.strip().str.lower()
            
            # Get top categories (keep top 15 to avoid sparse features)
            top_categories = df[category_col].value_counts().head(15).index.tolist()
            
            # One-hot encode
            for cat in top_categories:
                safe_cat_name = cat.replace(' ', '_').replace('-', '_')
                df[f'category_{safe_cat_name}'] = (df[category_col] == cat).astype(int)
            
            print(f"[INFO] ✓ Created: {len(top_categories)} one-hot encoded category features")
        return df
    
    def create_indoor_flag(self, df, category_col):
        """Create indoor/outdoor flag based on category."""
        if category_col and category_col in df.columns:
            def is_indoor(category):
                if pd.isna(category):
                    return 0
                category_lower = str(category).lower()
                return int(any(indoor in category_lower for indoor in self.indoor_categories))
            
            df['indoor_flag'] = df[category_col].apply(is_indoor)
            indoor_count = df['indoor_flag'].sum()
            print(f"[INFO] ✓ Created: indoor_flag ({indoor_count} indoor POIs)")
        return df
    
    def create_activity_intensity(self, df, category_col):
        """Create activity intensity score (1-5 scale) based on category."""
        if category_col and category_col in df.columns:
            def get_intensity(category):
                if pd.isna(category):
                    return 3  # neutral
                category_lower = str(category).lower()
                
                # Check high intensity
                for keyword in self.intensity_mapping['high']:
                    if keyword in category_lower:
                        return 5
                
                # Check low intensity
                for keyword in self.intensity_mapping['low']:
                    if keyword in category_lower:
                        return 2
                
                # Check medium intensity
                for keyword in self.intensity_mapping['medium']:
                    if keyword in category_lower:
                        return 3
                
                return 3  # default medium
            
            df['activity_intensity_score'] = df[category_col].apply(get_intensity)
            print("[INFO] ✓ Created: activity_intensity_score")
        return df
    
    def remove_irrelevant_columns(self, df, columns):
        """Remove columns not needed for ML training."""
        # Columns to remove
        remove_cols = ['poi_id', 'name', 'description', 'opening_hours', 
                      'booking_link', 'data_source', 'created_date', 'city',
                      'province', 'poi_type']
        
        # Add detected original columns to remove (keep engineered features only)
        if columns['category']:
            remove_cols.append(columns['category'])
        if columns['rating']:
            remove_cols.append(columns['rating'])
        if columns['review_count']:
            remove_cols.append(columns['review_count'])
        if columns['price']:
            remove_cols.append(columns['price'])
        
        # Remove columns that exist
        cols_to_drop = [col for col in remove_cols if col in df.columns]
        df_final = df.drop(columns=cols_to_drop)
        
        print(f"[INFO] Removed {len(cols_to_drop)} irrelevant columns")
        return df_final
    
    def save_data(self, df):
        """Save processed dataset to CSV."""
        self.output_file.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(self.output_file, index=False)
        print(f"\n[SUCCESS] ✓ Processed dataset saved to: {self.output_file}")
        print(f"[SUCCESS] Final shape: {df.shape}")
        print(f"[SUCCESS] Features: {list(df.columns)}")
    
    def run_pipeline(self):
        """Execute the complete feature engineering pipeline."""
        print("=" * 70)
        print("TripBond POI Feature Engineering Pipeline")
        print("=" * 70)
        
        # Step 1: Load data
        df = self.load_data()
        
        # Step 2: Detect columns
        print("\n" + "=" * 70)
        print("Detecting Columns")
        print("=" * 70)
        columns = self.detect_columns(df)
        
        # Step 3: Clean data
        print("\n" + "=" * 70)
        print("Data Cleaning")
        print("=" * 70)
        df = self.clean_data(df, columns)
        
        # Step 4: Feature engineering
        print("\n" + "=" * 70)
        print("Feature Engineering")
        print("=" * 70)
        df = self.create_normalized_rating(df, columns['rating'])
        df = self.create_popularity_score(df, columns['review_count'])
        df = self.create_normalized_price(df, columns['price'])
        df = self.create_category_encoding(df, columns['category'])
        df = self.create_indoor_flag(df, columns['category'])
        df = self.create_activity_intensity(df, columns['category'])
        
        # Step 5: Remove irrelevant columns
        print("\n" + "=" * 70)
        print("Finalizing Dataset")
        print("=" * 70)
        df = self.remove_irrelevant_columns(df, columns)
        
        # Step 6: Save
        self.save_data(df)
        
        print("\n" + "=" * 70)
        print("Pipeline Complete!")
        print("=" * 70)


def main():
    """Main execution function."""
    engineer = POIFeatureEngineer()
    engineer.run_pipeline()


if __name__ == "__main__":
    main()
