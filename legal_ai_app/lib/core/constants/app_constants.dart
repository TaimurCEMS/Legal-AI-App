/// App-wide constants
class AppConstants {
  // API Configuration
  static const int apiTimeoutSeconds = 30;
  static const int maxRetryAttempts = 3;
  static const Duration apiTimeout = Duration(seconds: apiTimeoutSeconds);

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 128;
  static const int minOrgNameLength = 1;
  static const int maxOrgNameLength = 100;
  static const int maxOrgDescriptionLength = 500;
  static const int maxClientNameLength = 200;
  static const int maxClientNotesLength = 1000;

  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;
  static const int defaultSearchLimit = 20;
  static const int maxSearchLimit = 50;

  // Error Messages
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorTimeout = 'Request timed out. Please try again.';
  static const String errorUnknown = 'An unexpected error occurred. Please try again.';
  static const String errorUnauthorized = 'You are not authorized to perform this action.';
  static const String errorNotFound = 'Resource not found.';
  static const String errorValidation = 'Please check your input and try again.';

  // Success Messages (use AppLabels for Firm/Matter terminology in UI)
  static const String successOrgCreated = 'Firm created successfully!';
  static const String successOrgJoined = 'Successfully joined firm!';
  static const String successPasswordReset = 'Password reset email sent!';

  // Feature Flags (for future use)
  static const bool enableDarkMode = false; // Will be enabled in future
  static const bool enableBiometricAuth = false; // Will be enabled in future
  static const bool enableOfflineMode = false; // Will be enabled in future

  // App Info
  static const String appName = 'Legal AI App';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@legalai.app';

  // Firebase Configuration
  static const String firebaseProjectId = 'legal-ai-app-1203e';
  static const String firebaseRegion = 'us-central1';

  // Cloud Function Names
  static const String functionOrgCreate = 'org.create';
  static const String functionOrgJoin = 'org.join';
  static const String functionMemberGetMyMembership = 'member.getMyMembership';

  // Storage Paths (for future use)
  static const String storageDocumentsPath = 'documents';
  static const String storageAvatarsPath = 'avatars';

  // Cache Keys (for future use)
  static const String cacheKeyUserProfile = 'user_profile';
  static const String cacheKeyOrgList = 'org_list';
  static const String cacheKeySelectedOrg = 'selected_org';

  // Animation Durations
  static const Duration animationShort = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationLong = Duration(milliseconds: 500);

  // Debounce Durations
  static const Duration debounceSearch = Duration(milliseconds: 300);
  static const Duration debounceTyping = Duration(milliseconds: 500);
}
