import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_ai_app/firebase_options.dart';

/// Initialize Firebase for tests
/// 
/// Note: Firebase requires platform channels which are not available in unit tests.
/// This will work for:
/// - Integration tests (flutter drive or integration_test package)
/// - Widget tests that run on a device/emulator
/// 
/// For unit tests, consider mocking CloudFunctionsService instead.
/// 
/// Call this in setUpAll() before running tests that require Firebase
Future<void> setupFirebaseForTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Check if Firebase is already initialized
  try {
    Firebase.app();
    // Already initialized, no need to initialize again
    return;
  } catch (e) {
    // Not initialized, proceed with initialization
  }
  
  try {
    // Initialize Firebase with test options
    // For tests, we use the same Firebase project
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If initialization fails (e.g., in unit tests without platform channels),
    // this is expected. Tests that require Firebase will need to be:
    // 1. Run as integration tests, or
    // 2. Use mocked services instead
    print('Warning: Firebase initialization failed in test environment: $e');
    print('This is expected for unit tests. Consider using mocks or integration tests.');
    rethrow;
  }
}

/// Clean up Firebase after tests
/// Call this in tearDownAll() if needed
Future<void> teardownFirebaseForTests() async {
  try {
    await Firebase.app().delete();
  } catch (e) {
    // Ignore errors if app is already deleted or doesn't exist
  }
}
