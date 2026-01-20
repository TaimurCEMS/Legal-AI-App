# Automated Testing Guide

**Purpose:** Run automated tests to verify state management, UI components, and logic before manual testing in Chrome.

**Last Updated:** 2026-01-19

---

## Quick Start

### Run All Tests:
```cmd
run-tests.bat
```

Or from project root:
```cmd
cd legal_ai_app
flutter test
```

---

## What Gets Tested

### ✅ State Management Tests (`test/state_management_test.dart`)
- **OrgProvider:**
  - Initial state (no org selected)
  - Setting selected org
  - Clearing org
  - State updates

- **CaseProvider:**
  - Initial state (empty cases list)
  - Cases list immutability
  - State management

### ✅ UI Component Tests (`test/ui_components_test.dart`)
- **PrimaryButton:**
  - Displays label correctly
  - Calls onPressed when tapped
  - Shows loading state

- **SecondaryButton:**
  - Displays label correctly
  - Calls onPressed when tapped

- **AppTextField:**
  - Displays label and hint
  - Text input handling

- **LoadingSpinner:**
  - Displays message
  - Shows spinner

- **EmptyStateWidget:**
  - Displays title and message
  - Shows icon

### ✅ State Persistence Tests (`test/state_persistence_test.dart`)
- **SharedPreferences:**
  - Saves and loads org ID
  - Saves and loads user ID
  - Clears org data
  - Persists across instances

---

## Test Commands

### Run All Tests:
```cmd
run-tests.bat
```

### Run Specific Test Suite:
```cmd
cd legal_ai_app
flutter test test/state_management_test.dart
flutter test test/ui_components_test.dart
flutter test test/state_persistence_test.dart
```

### Run with Coverage:
```cmd
cd legal_ai_app
flutter test --coverage
```

---

## What Tests DON'T Cover

These still require manual testing in Chrome:

1. **End-to-End Flows:**
   - Create org → Create case → Refresh → Verify persistence
   - Switch tabs → Verify state preservation
   - Navigation flows

2. **Backend Integration:**
   - Actual API calls to Cloud Functions
   - Firestore reads/writes
   - Authentication flows

3. **Visual Testing:**
   - UI appearance
   - Responsive layouts
   - Theme application

4. **Performance:**
   - Load times
   - Memory usage
   - Network handling

---

## Test Workflow

### Before Running App in Chrome:

1. **Run Automated Tests:**
   ```cmd
   run-tests.bat
   ```

2. **If All Tests Pass:**
   - ✅ State management logic verified
   - ✅ UI components work correctly
   - ✅ State persistence works
   - **Ready to run in Chrome**

3. **If Tests Fail:**
   - ❌ Fix failing tests first
   - ❌ Don't run app until tests pass

4. **Run App in Chrome:**
   ```cmd
   cd legal_ai_app
   flutter run -d chrome
   ```

5. **Manual Testing:**
   - Test end-to-end flows
   - Verify visual appearance
   - Test backend integration

---

## Adding New Tests

### State Management Test:
```dart
test('description', () {
  // Arrange
  final provider = YourProvider();
  
  // Act
  provider.someMethod();
  
  // Assert
  expect(provider.someProperty, equals(expectedValue));
});
```

### UI Component Test:
```dart
testWidgets('description', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: YourWidget(),
    ),
  );
  
  expect(find.text('Expected Text'), findsOneWidget);
});
```

---

## Test Coverage Goals

- **State Management:** 80%+ coverage
- **UI Components:** 100% coverage (all widgets)
- **State Persistence:** 100% coverage (all persistence logic)

---

## Troubleshooting

### Tests Fail to Run:
1. Run `flutter pub get` to install dependencies
2. Check for compilation errors: `flutter analyze`
3. Verify test files are in `test/` directory

### Mock Issues:
- Tests use `SharedPreferences.setMockInitialValues({})` for persistence
- No actual Firebase calls in tests (use mocks if needed)

---

**Next Steps:**
1. Run `run-tests.bat` before every Chrome test session
2. Add tests for new features
3. Keep test coverage high
