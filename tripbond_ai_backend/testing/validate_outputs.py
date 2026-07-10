"""
TripBond AI Output Validation
===============================
Validates AI-generated recommendations and itineraries for quality,
structure, and consistency.

Author: TripBond AI Team
Date: 2026-02-21
"""

import sys
import pandas as pd
import numpy as np
from pathlib import Path


class TripBondOutputValidator:
    """Validator for TripBond AI outputs."""
    
    def __init__(self):
        """Initialize validator."""
        self.project_root = Path(__file__).parent.parent
        self.data_dir = self.project_root / "data"
        
        self.passed_checks = []
        self.failed_checks = []
        self.warnings = []
    
    def print_header(self, title):
        """Print formatted section header."""
        print("\n" + "=" * 70)
        print(title)
        print("=" * 70)
    
    def print_check(self, check_name, passed, message=""):
        """
        Print validation check result.
        
        Args:
            check_name: Name of the check
            passed: Whether check passed
            message: Additional message
        """
        status = "PASS" if passed else "FAIL"
        symbol = "✓" if passed else "✗"
        print(f"[{symbol} {status}] {check_name}")
        
        if message:
            print(f"          {message}")
        
        if passed:
            self.passed_checks.append(check_name)
        else:
            self.failed_checks.append(check_name)
    
    def print_warning(self, message):
        """Print warning message."""
        print(f"[⚠ WARN] {message}")
        self.warnings.append(message)
    
    def validate_probability_range(self, df, column_name, dataset_name):
        """
        Validate that probability values are in [0, 1] range.
        
        Args:
            df: DataFrame
            column_name: Column to validate
            dataset_name: Name for reporting
            
        Returns:
            bool: True if valid
        """
        if column_name not in df.columns:
            self.print_warning(f"{dataset_name}: Column '{column_name}' not found")
            return True  # Not a failure, just missing
        
        values = df[column_name].dropna()
        
        if len(values) == 0:
            self.print_check(
                f"{dataset_name}: {column_name} range check",
                False,
                "No valid values found"
            )
            return False
        
        min_val = values.min()
        max_val = values.max()
        
        if min_val >= 0 and max_val <= 1:
            self.print_check(
                f"{dataset_name}: {column_name} in [0,1]",
                True,
                f"Range: [{min_val:.4f}, {max_val:.4f}]"
            )
            return True
        else:
            self.print_check(
                f"{dataset_name}: {column_name} in [0,1]",
                False,
                f"OUT OF RANGE: [{min_val:.4f}, {max_val:.4f}]"
            )
            return False
    
    def validate_variance(self, df, column_name, dataset_name, min_std=0.01):
        """
        Validate that values have sufficient variance.
        
        Args:
            df: DataFrame
            column_name: Column to validate
            dataset_name: Name for reporting
            min_std: Minimum acceptable standard deviation
            
        Returns:
            bool: True if valid
        """
        if column_name not in df.columns:
            return True  # Not a failure
        
        values = df[column_name].dropna()
        
        if len(values) < 2:
            self.print_check(
                f"{dataset_name}: {column_name} variance",
                False,
                "Not enough values to compute variance"
            )
            return False
        
        std_dev = values.std()
        
        if std_dev > min_std:
            self.print_check(
                f"{dataset_name}: {column_name} has variance",
                True,
                f"Std Dev: {std_dev:.4f}"
            )
            return True
        else:
            self.print_check(
                f"{dataset_name}: {column_name} has variance",
                False,
                f"Too low: {std_dev:.4f} (min: {min_std})"
            )
            return False
    
    def validate_category_diversity(self, df, dataset_name):
        """
        Validate that POIs span multiple categories.
        
        Args:
            df: DataFrame
            dataset_name: Name for reporting
            
        Returns:
            bool: True if valid
        """
        category_cols = ['category', 'poi_category', 'poi_type']
        
        category_col = None
        for col in category_cols:
            if col in df.columns:
                category_col = col
                break
        
        if not category_col:
            self.print_warning(f"{dataset_name}: No category column found")
            return True  # Not a failure
        
        categories = df[category_col].dropna().unique()
        n_categories = len(categories)
        
        if n_categories > 1:
            self.print_check(
                f"{dataset_name}: Category diversity",
                True,
                f"{n_categories} unique categories"
            )
            return True
        else:
            self.print_check(
                f"{dataset_name}: Category diversity",
                False,
                f"Only {n_categories} category found"
            )
            return False
    
    def validate_single_user_recommendations(self):
        """Validate single user recommendation output."""
        self.print_header("VALIDATION 1: Single User Recommendations")
        
        file_path = self.data_dir / "top_pois_for_user.csv"
        
        if not file_path.exists():
            self.print_check("Single user file exists", False, "File not found")
            return False
        
        try:
            df = pd.read_csv(file_path)
            self.print_check(
                "Single user file loaded",
                True,
                f"{len(df)} POIs"
            )
        except Exception as e:
            self.print_check("Single user file loaded", False, str(e))
            return False
        
        # Validate probability range
        self.validate_probability_range(
            df, 'predicted_like_prob', 'Single User'
        )
        
        # Validate variance
        self.validate_variance(
            df, 'predicted_like_prob', 'Single User'
        )
        
        # Validate category diversity
        self.validate_category_diversity(df, 'Single User')
        
        return True
    
    def validate_group_recommendations(self):
        """Validate group recommendation output."""
        self.print_header("VALIDATION 2: Group Recommendations")
        
        file_path = self.data_dir / "top_pois_for_group.csv"
        
        if not file_path.exists():
            self.print_check("Group file exists", False, "File not found")
            return False
        
        try:
            df = pd.read_csv(file_path)
            self.print_check(
                "Group file loaded",
                True,
                f"{len(df)} POIs"
            )
        except Exception as e:
            self.print_check("Group file loaded", False, str(e))
            return False
        
        # Validate final_group_score range
        self.validate_probability_range(
            df, 'final_group_score', 'Group'
        )
        
        # Validate avg_score range
        self.validate_probability_range(
            df, 'avg_score', 'Group'
        )
        
        # Validate fairness_score range
        self.validate_probability_range(
            df, 'fairness_score', 'Group'
        )
        
        # Validate variance
        self.validate_variance(
            df, 'final_group_score', 'Group'
        )
        
        # Validate category diversity
        self.validate_category_diversity(df, 'Group')
        
        return True
    
    def validate_itinerary_structure(self, file_path, itinerary_name, expected_stops=5):
        """
        Validate itinerary structure.
        
        Args:
            file_path: Path to itinerary CSV
            itinerary_name: Name for reporting
            expected_stops: Expected number of stops
            
        Returns:
            tuple: (bool success, DataFrame or None)
        """
        if not file_path.exists():
            self.print_check(f"{itinerary_name}: File exists", False, "File not found")
            return False, None
        
        try:
            df = pd.read_csv(file_path)
            self.print_check(
                f"{itinerary_name}: File loaded",
                True,
                f"{len(df)} stops"
            )
        except Exception as e:
            self.print_check(f"{itinerary_name}: File loaded", False, str(e))
            return False, None
        
        # Check number of stops
        if len(df) == expected_stops:
            self.print_check(
                f"{itinerary_name}: Correct number of stops",
                True,
                f"{len(df)} stops"
            )
        else:
            self.print_check(
                f"{itinerary_name}: Correct number of stops",
                False,
                f"Expected {expected_stops}, got {len(df)}"
            )
        
        # Check POI uniqueness
        poi_col = None
        for col in ['poi_id', 'POI_ID', 'poi']:
            if col in df.columns:
                poi_col = col
                break
        
        if poi_col:
            poi_ids = df[poi_col].tolist()
            unique_pois = len(set(poi_ids))
            
            if unique_pois == len(poi_ids):
                self.print_check(
                    f"{itinerary_name}: All POIs unique",
                    True,
                    f"{unique_pois} unique POIs"
                )
            else:
                self.print_check(
                    f"{itinerary_name}: All POIs unique",
                    False,
                    f"Duplicates found: {len(poi_ids) - unique_pois}"
                )
        else:
            self.print_warning(f"{itinerary_name}: No POI ID column found")
        
        # Check cumulative cost
        cumulative_col = None
        for col in ['cumulative_cost', 'total_cost', 'cumulative_time']:
            if col in df.columns:
                cumulative_col = col
                break
        
        if cumulative_col:
            cumulative_costs = df[cumulative_col].tolist()
            
            # Check strictly increasing (except first can be 0)
            is_increasing = all(
                cumulative_costs[i] <= cumulative_costs[i+1]
                for i in range(len(cumulative_costs)-1)
            )
            
            if is_increasing:
                self.print_check(
                    f"{itinerary_name}: Cumulative cost increasing",
                    True,
                    f"0 → {cumulative_costs[-1]:.2f}"
                )
            else:
                self.print_check(
                    f"{itinerary_name}: Cumulative cost increasing",
                    False,
                    "Cost decreases somewhere"
                )
            
            # Check final cost > 0
            final_cost = cumulative_costs[-1]
            if final_cost > 0:
                self.print_check(
                    f"{itinerary_name}: Final cost > 0",
                    True,
                    f"Final: {final_cost:.2f}"
                )
            else:
                self.print_check(
                    f"{itinerary_name}: Final cost > 0",
                    False,
                    f"Final cost is {final_cost}"
                )
        
        # Check no negative leg costs
        leg_cost_col = None
        for col in ['leg_cost_from_previous', 'leg_cost', 'travel_time']:
            if col in df.columns:
                leg_cost_col = col
                break
        
        if leg_cost_col:
            leg_costs = df[leg_cost_col].dropna()
            negative_costs = leg_costs[leg_costs < 0]
            
            if len(negative_costs) == 0:
                self.print_check(
                    f"{itinerary_name}: No negative leg costs",
                    True,
                    f"All {len(leg_costs)} costs >= 0"
                )
            else:
                self.print_check(
                    f"{itinerary_name}: No negative leg costs",
                    False,
                    f"{len(negative_costs)} negative costs found"
                )
        
        return True, df
    
    def validate_greedy_itinerary(self):
        """Validate greedy itinerary."""
        self.print_header("VALIDATION 3: Greedy Itinerary Structure")
        
        file_path = self.data_dir / "group_itinerary_greedy.csv"
        success, df = self.validate_itinerary_structure(file_path, "Greedy")
        
        return success, df
    
    def validate_ga_itinerary(self):
        """Validate GA itinerary."""
        self.print_header("VALIDATION 4: GA Itinerary Structure")
        
        file_path = self.data_dir / "group_itinerary_ga.csv"
        success, df = self.validate_itinerary_structure(file_path, "GA")
        
        return success, df
    
    def compare_itineraries(self, greedy_df, ga_df):
        """
        Compare greedy vs GA itineraries.
        
        Args:
            greedy_df: Greedy itinerary DataFrame
            ga_df: GA itinerary DataFrame
        """
        self.print_header("VALIDATION 5: Greedy vs GA Comparison")
        
        if greedy_df is None or ga_df is None:
            self.print_warning("Cannot compare - one or both itineraries missing")
            return
        
        # Compare total costs
        cumulative_col = None
        for col in ['cumulative_cost', 'total_cost', 'cumulative_time']:
            if col in greedy_df.columns and col in ga_df.columns:
                cumulative_col = col
                break
        
        if cumulative_col:
            greedy_cost = greedy_df[cumulative_col].iloc[-1]
            ga_cost = ga_df[cumulative_col].iloc[-1]
            
            print(f"\nTotal Travel Cost:")
            print(f"  Greedy: {greedy_cost:.2f}")
            print(f"  GA:     {ga_cost:.2f}")
            
            if ga_cost < greedy_cost:
                improvement = ((greedy_cost - ga_cost) / greedy_cost) * 100
                self.print_check(
                    "GA improves over Greedy",
                    True,
                    f"Reduction: {improvement:.2f}%"
                )
            elif ga_cost == greedy_cost:
                self.print_check(
                    "GA matches Greedy",
                    True,
                    "Equal performance"
                )
            else:
                difference = ((ga_cost - greedy_cost) / greedy_cost) * 100
                self.print_warning(
                    f"GA cost higher by {difference:.2f}% (may optimize different objectives)"
                )
        
        # Check if GA has fitness score
        if 'fitness' in ga_df.columns:
            fitness = ga_df['fitness'].iloc[0] if 'fitness' in ga_df.columns else None
            if fitness:
                print(f"\nGA Fitness Score: {fitness:.4f}")
                self.print_check(
                    "GA fitness score available",
                    True,
                    f"Fitness: {fitness:.4f}"
                )
    
    def print_summary(self):
        """Print final validation summary."""
        self.print_header("VALIDATION SUMMARY")
        
        total_checks = len(self.passed_checks) + len(self.failed_checks)
        pass_count = len(self.passed_checks)
        fail_count = len(self.failed_checks)
        warn_count = len(self.warnings)
        
        print(f"\nTotal Checks:    {total_checks}")
        print(f"Passed:          {pass_count} ✓")
        print(f"Failed:          {fail_count} ✗")
        print(f"Warnings:        {warn_count} ⚠")
        
        if fail_count > 0:
            print("\n[FAILED CHECKS]")
            for check in self.failed_checks:
                print(f"  ✗ {check}")
        
        if warn_count > 0:
            print("\n[WARNINGS]")
            for warning in self.warnings:
                print(f"  ⚠ {warning}")
        
        print("\n" + "=" * 70)
        
        if fail_count == 0:
            print("RESULT: ALL VALIDATIONS PASSED ✓")
            print("=" * 70)
            return True
        else:
            print("RESULT: SOME VALIDATIONS FAILED ✗")
            print("=" * 70)
            return False
    
    def run_all_validations(self):
        """Run complete validation suite."""
        print("\n" + "=" * 70)
        print("TripBond AI Output Validation Suite")
        print("=" * 70)
        print(f"Project Root: {self.project_root}")
        
        # Run validations
        self.validate_single_user_recommendations()
        self.validate_group_recommendations()
        greedy_success, greedy_df = self.validate_greedy_itinerary()
        ga_success, ga_df = self.validate_ga_itinerary()
        
        # Compare itineraries
        if greedy_success and ga_success:
            self.compare_itineraries(greedy_df, ga_df)
        
        # Print summary and exit
        result = self.print_summary()
        
        if result:
            sys.exit(0)
        else:
            sys.exit(1)


def main():
    """Main entry point."""
    validator = TripBondOutputValidator()
    validator.run_all_validations()


if __name__ == "__main__":
    main()
