"""
TripBond AI Backend Smoke Test
================================
Validates the complete pipeline by running all critical scripts
and verifying their outputs.

Author: TripBond AI Team
Date: 2026-02-21
"""

import sys
import subprocess
from pathlib import Path
from datetime import datetime


class TripBondSmokeTest:
    """Smoke test runner for TripBond AI backend."""
    
    def __init__(self):
        """Initialize smoke test."""
        self.project_root = Path(__file__).parent.parent
        self.passed_tests = []
        self.failed_tests = []
        self.warnings = []
    
    def print_header(self, title):
        """Print formatted section header."""
        print("\n" + "=" * 70)
        print(title)
        print("=" * 70)
    
    def print_test(self, test_name, status, message=""):
        """Print test result."""
        status_symbol = "✓" if status == "PASS" else "✗" if status == "FAIL" else "⚠"
        status_str = f"[{status_symbol} {status}]"
        print(f"{status_str:<12} {test_name}")
        if message:
            print(f"             {message}")
    
    def check_file_exists(self, file_path, required=True):
        """
        Check if a file exists.
        
        Args:
            file_path: Path to file
            required: Whether file is required
            
        Returns:
            bool: True if exists or not required, False otherwise
        """
        exists = file_path.exists()
        
        if exists:
            size = file_path.stat().st_size
            self.print_test(
                f"File: {file_path.relative_to(self.project_root)}",
                "PASS",
                f"Size: {size:,} bytes"
            )
            self.passed_tests.append(str(file_path))
            return True
        else:
            if required:
                self.print_test(
                    f"File: {file_path.relative_to(self.project_root)}",
                    "FAIL",
                    "File not found"
                )
                self.failed_tests.append(str(file_path))
                return False
            else:
                self.print_test(
                    f"File: {file_path.relative_to(self.project_root)}",
                    "WARN",
                    "Optional file not found"
                )
                self.warnings.append(str(file_path))
                return True
    
    def run_script(self, script_path, script_name):
        """
        Run a Python script and capture output.
        
        Args:
            script_path: Path to script
            script_name: Display name
            
        Returns:
            bool: True if succeeded, False otherwise
        """
        print(f"\n[RUN] {script_name}")
        print(f"      Command: python {script_path.relative_to(self.project_root)}")
        
        try:
            # Set environment to handle Unicode output on Windows
            import os
            env = os.environ.copy()
            env['PYTHONIOENCODING'] = 'utf-8'
            
            result = subprocess.run(
                [sys.executable, str(script_path)],
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=120,
                env=env
            )
            
            if result.returncode == 0:
                self.print_test(script_name, "PASS", "Executed successfully")
                self.passed_tests.append(script_name)
                return True
            else:
                self.print_test(
                    script_name,
                    "FAIL",
                    f"Exit code: {result.returncode}"
                )
                if result.stderr:
                    print(f"      Error: {result.stderr[:200]}")
                self.failed_tests.append(script_name)
                return False
                
        except subprocess.TimeoutExpired:
            self.print_test(script_name, "FAIL", "Timeout (>120s)")
            self.failed_tests.append(script_name)
            return False
            
        except Exception as e:
            self.print_test(script_name, "FAIL", f"Exception: {str(e)}")
            self.failed_tests.append(script_name)
            return False
    
    def test_prerequisite_files(self):
        """Test that all prerequisite files exist."""
        self.print_header("STEP 1: Checking Prerequisite Files")
        
        required_files = [
            self.project_root / "models" / "rf_model.pkl",
            self.project_root / "models" / "feature_names.txt",
            self.project_root / "data" / "poi_features_ready.csv",
            self.project_root / "data" / "synthetic_users.csv",
        ]
        
        optional_files = [
            self.project_root / "data" / "top_pois_for_user.csv",
            self.project_root / "data" / "top_pois_for_group.csv",
        ]
        
        all_passed = True
        
        for file_path in required_files:
            if not self.check_file_exists(file_path, required=True):
                all_passed = False
        
        for file_path in optional_files:
            self.check_file_exists(file_path, required=False)
        
        return all_passed
    
    def test_predict_pois(self):
        """Test single user POI prediction."""
        self.print_header("STEP 2: Testing Single User POI Prediction")
        
        script_path = self.project_root / "api" / "predict_pois.py"
        
        if not script_path.exists():
            self.print_test("predict_pois.py", "FAIL", "Script not found")
            self.failed_tests.append("predict_pois.py")
            return False
        
        # Run script
        success = self.run_script(script_path, "predict_pois.py")
        
        if success:
            # Verify output
            output_file = self.project_root / "data" / "top_pois_for_user.csv"
            if self.check_file_exists(output_file, required=True):
                return True
            else:
                return False
        
        return False
    
    def test_group_recommendations(self):
        """Test group recommendations."""
        self.print_header("STEP 3: Testing Group Recommendations")
        
        script_path = self.project_root / "api" / "group_recommendations.py"
        
        if not script_path.exists():
            self.print_test("group_recommendations.py", "FAIL", "Script not found")
            self.failed_tests.append("group_recommendations.py")
            return False
        
        # Run script
        success = self.run_script(script_path, "group_recommendations.py")
        
        if success:
            # Verify output
            output_file = self.project_root / "data" / "top_pois_for_group.csv"
            if self.check_file_exists(output_file, required=True):
                return True
            else:
                return False
        
        return False
    
    def test_greedy_itinerary(self):
        """Test greedy itinerary builder."""
        self.print_header("STEP 4: Testing Greedy Itinerary Builder")
        
        script_path = self.project_root / "api" / "build_itinerary.py"
        
        if not script_path.exists():
            self.print_test("build_itinerary.py", "FAIL", "Script not found")
            self.failed_tests.append("build_itinerary.py")
            return False
        
        # Run script
        success = self.run_script(script_path, "build_itinerary.py")
        
        if success:
            # Verify output
            output_file = self.project_root / "data" / "group_itinerary_greedy.csv"
            if self.check_file_exists(output_file, required=True):
                return True
            else:
                return False
        
        return False
    
    def test_ga_itinerary(self):
        """Test GA itinerary optimizer."""
        self.print_header("STEP 5: Testing GA Itinerary Optimizer")
        
        script_path = self.project_root / "api" / "build_itinerary_ga.py"
        
        if not script_path.exists():
            self.print_test("build_itinerary_ga.py", "FAIL", "Script not found")
            self.failed_tests.append("build_itinerary_ga.py")
            return False
        
        # Run script
        success = self.run_script(script_path, "build_itinerary_ga.py")
        
        if success:
            # Verify output
            output_file = self.project_root / "data" / "group_itinerary_ga.csv"
            if self.check_file_exists(output_file, required=True):
                return True
            else:
                return False
        
        return False
    
    def print_summary(self):
        """Print final test summary."""
        self.print_header("TEST SUMMARY")
        
        total_tests = len(self.passed_tests) + len(self.failed_tests)
        pass_count = len(self.passed_tests)
        fail_count = len(self.failed_tests)
        warn_count = len(self.warnings)
        
        print(f"\nTotal Tests:     {total_tests}")
        print(f"Passed:          {pass_count} ✓")
        print(f"Failed:          {fail_count} ✗")
        print(f"Warnings:        {warn_count} ⚠")
        
        if fail_count > 0:
            print("\n[FAILED TESTS]")
            for test in self.failed_tests:
                print(f"  ✗ {test}")
        
        if warn_count > 0:
            print("\n[WARNINGS]")
            for warning in self.warnings:
                print(f"  ⚠ {warning}")
        
        print("\n" + "=" * 70)
        
        if fail_count == 0:
            print("RESULT: ALL TESTS PASSED ✓")
            print("=" * 70)
            return True
        else:
            print("RESULT: SOME TESTS FAILED ✗")
            print("=" * 70)
            return False
    
    def run_all_tests(self):
        """Run complete smoke test suite."""
        print("\n" + "=" * 70)
        print("TripBond AI Backend - Smoke Test Suite")
        print("=" * 70)
        print(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Project Root: {self.project_root}")
        
        # Run tests in order
        all_passed = True
        
        # Step 1: Check prerequisites
        if not self.test_prerequisite_files():
            print("\n[ERROR] Missing required prerequisite files!")
            print("[ERROR] Cannot continue with pipeline tests.")
            all_passed = False
        else:
            # Step 2-5: Run pipeline
            if not self.test_predict_pois():
                all_passed = False
            
            if not self.test_group_recommendations():
                all_passed = False
            
            if not self.test_greedy_itinerary():
                all_passed = False
            
            if not self.test_ga_itinerary():
                all_passed = False
        
        # Print summary
        result = self.print_summary()
        
        # Exit with appropriate code
        if result:
            sys.exit(0)
        else:
            sys.exit(1)


def main():
    """Main entry point."""
    test_suite = TripBondSmokeTest()
    test_suite.run_all_tests()


if __name__ == "__main__":
    main()
