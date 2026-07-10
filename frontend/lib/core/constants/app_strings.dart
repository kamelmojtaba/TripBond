/// App-wide string constants for consistent messaging
class AppStrings {
  AppStrings._(); // Private constructor to prevent instantiation

  // App Info
  static const String appName = 'TripBond';
  static const String appTagline = 'Bond through travel';

  // Common Labels
  static const String ok = 'OK';
  static const String cancel = 'Cancel';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String done = 'Done';
  static const String next = 'Next';
  static const String back = 'Back';
  static const String skip = 'Skip';
  static const String getStarted = 'Get Started';
  static const String continueText = 'Continue';
  static const String submit = 'Submit';
  static const String confirm = 'Confirm';

  // Authentication
  static const String login = 'Login';
  static const String register = 'Register';
  static const String signUp = 'Sign Up';
  static const String signIn = 'Sign In';
  static const String logout = 'Logout';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String createAccount = 'Create Account';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String dontHaveAccount = "Don't have an account?";

  // Form Fields
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String fullName = 'Full Name';
  static const String username = 'Username';
  static const String phoneNumber = 'Phone Number';

  // Placeholders
  static const String emailPlaceholder = 'Enter your email';
  static const String passwordPlaceholder = 'Enter your password';
  static const String namePlaceholder = 'Enter your name';

  // Validation Messages
  static const String emailRequired = 'Email is required';
  static const String passwordRequired = 'Password is required';
  static const String invalidEmail = 'Invalid email address';
  static const String passwordTooShort =
      'Password must be at least 8 characters';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String fieldRequired = 'This field is required';

  // MBTI Related
  static const String mbtiIntroTitle = 'Dear Bonder,\nlet\'s get to know\nyou!';
  static const String agree = 'Agree';
  static const String neutral = 'Natural';
  static const String disagree = 'Disagree';

  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork =
      'Network error. Please check your connection.';
  static const String errorUnauthorized = 'Unauthorized. Please login again.';
  static const String errorNotFound = 'Resource not found.';

  // Success Messages
  static const String successGeneric = 'Success!';
  static const String accountCreated = 'Account created successfully!';
  static const String passwordReset = 'Password reset successfully!';
  static const String profileUpdated = 'Profile updated successfully!';

  // Loading Messages
  static const String loading = 'Loading...';
  static const String pleaseWait = 'Please wait...';
  static const String processing = 'Processing...';

  // Empty States
  static const String noDataAvailable = 'No data available';
  static const String noResultsFound = 'No results found';
  static const String noTripsYet = 'No trips yet';

  // Social Authentication
  static const String continueWithGoogle = 'Continue with Google';
  static const String continueWithFacebook = 'Continue with Facebook';
  static const String continueWithApple = 'Continue with Apple';
  static const String orSignInWith = 'Or sign in with';
}
