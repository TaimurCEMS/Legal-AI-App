# Firebase Testing Setup

## Current Status

Your Firebase project (`legal-ai-app-1203e`) is configured, but **unit tests cannot directly use Firebase** because Firebase requires platform channels that aren't available in unit test environments.

## Options for Testing with Firebase

### Option 1: Use Firebase Emulators (Recommended for Local Testing)

Firebase Emulators allow you to test against local Firebase services without hitting production.

**Setup:**
1. Install Firebase Tools: `npm install -g firebase-tools`
2. Start emulators: `firebase emulators:start`
3. Configure tests to point to emulators

**Benefits:**
- Fast, isolated tests
- No production data risk
- Works in CI/CD

### Option 2: Mock Firebase Services (Best for Unit Tests)

Mock `CloudFunctionsService` and other Firebase-dependent services.

**Example:**
```dart
// Create a mock CloudFunctionsService
class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}

// Use in tests
final mockService = MockCloudFunctionsService();
when(mockService.callFunction(any, any)).thenAnswer(...);
```

**Benefits:**
- Fast unit tests
- No external dependencies
- Full control over responses

### Option 3: Integration Tests (For Real Firebase)

Use `integration_test` package to test against your real Firebase project.

**Setup:**
1. Add `integration_test` to `dev_dependencies`
2. Create tests in `integration_test/` directory
3. Run with `flutter test integration_test/`

**Benefits:**
- Tests real Firebase integration
- Catches integration issues
- Can test full user flows

## Current Test Configuration

- **Unit tests**: Tests that don't require Firebase are passing ✅
- **Firebase-dependent tests**: Currently skipped (need one of the options above)

## Recommended Next Steps

1. **For immediate testing**: Use mocks (Option 2) - fastest to implement
2. **For comprehensive testing**: Set up emulators (Option 1) - best balance
3. **For production validation**: Add integration tests (Option 3) - most realistic

## Quick Start: Using Mocks

1. Create mock classes using `mockito`
2. Inject mocks into providers
3. Run tests without Firebase initialization

See `test_helper.dart` for Firebase initialization helper (for integration tests).
