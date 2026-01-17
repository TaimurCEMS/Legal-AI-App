# SLICE 1: Flutter UI Shell + Navigation + Auth Integration - Build Card

## 1) Purpose

Build the Flutter application foundation with navigation shell, reusable UI components, theme system, and Firebase Auth integration. This slice establishes the frontend infrastructure that all future slices will build upon.

## 2) Scope In ✅

- Flutter project setup and configuration
- Firebase Auth integration (login, signup, logout, password reset)
- Navigation shell (AppShell) with routing structure
- Theme system (colors, typography, spacing)
- Reusable UI widgets (Button, TextField, Card, etc.)
- Organization selection/gate screen
- Loading states and error handling UI
- Responsive layout structure
- State management setup (Provider/Riverpod/Bloc - choose one)

## 3) Scope Out ❌

- Backend API calls (Slice 2+)
- Case management UI (Slice 2)
- Client management UI (Slice 3)
- Document management UI (Slice 4)
- AI features UI (Slice 6+)
- Billing/subscription UI (Slice 13)
- Admin panel UI (Slice 15)
- Any business logic beyond UI presentation

## 4) Flutter Project Structure

### 4.1 Directory Structure

```
flutter_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app.dart                     # App widget with theme/routing
│   ├── core/
│   │   ├── theme/
│   │   │   ├── app_theme.dart      # Theme configuration
│   │   │   ├── colors.dart         # Color palette
│   │   │   ├── typography.dart     # Text styles
│   │   │   └── spacing.dart        # Spacing constants
│   │   ├── routing/
│   │   │   ├── app_router.dart     # Route definitions
│   │   │   └── route_names.dart    # Route name constants
│   │   └── constants/
│   │       └── app_constants.dart  # App-wide constants
│   ├── features/
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── signup_screen.dart
│   │   │   │   └── forgot_password_screen.dart
│   │   │   └── widgets/
│   │   │       └── auth_form_field.dart
│   │   ├── org_selection/
│   │   │   ├── screens/
│   │   │   │   ├── org_selection_screen.dart
│   │   │   │   └── org_create_screen.dart
│   │   │   └── widgets/
│   │   │       └── org_card.dart
│   │   └── home/
│   │       └── screens/
│   │           └── home_screen.dart (placeholder)
│   ├── shared/
│   │   ├── widgets/
│   │   │   ├── app_button.dart
│   │   │   ├── app_text_field.dart
│   │   │   ├── app_card.dart
│   │   │   ├── app_appbar.dart
│   │   │   ├── loading_indicator.dart
│   │   │   └── error_message.dart
│   │   └── layouts/
│   │       └── app_shell.dart      # Main navigation shell
│   └── services/
│       ├── auth_service.dart       # Firebase Auth wrapper
│       └── navigation_service.dart # Navigation helper
├── pubspec.yaml
└── README.md
```

### 4.2 Required Dependencies

**pubspec.yaml:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^latest
  firebase_auth: ^latest
  cloud_functions: ^latest
  
  # State Management (choose one)
  provider: ^latest  # OR riverpod, OR bloc
  
  # UI
  flutter_svg: ^latest
  google_fonts: ^latest  # For typography
  
  # Utilities
  intl: ^latest  # For date formatting
```

---

## 5) Theme System

### 5.1 Color Palette

**File:** `lib/core/theme/colors.dart`

```dart
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF1E3A8A);      // Deep blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E40AF);
  
  // Secondary colors
  static const Color secondary = Color(0xFF059669);   // Green
  static const Color secondaryLight = Color(0xFF10B981);
  
  // Neutral colors
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  
  // Text colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  
  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  
  // Border colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
}
```

### 5.2 Typography

**File:** `lib/core/theme/typography.dart`

```dart
class AppTypography {
  static TextStyle get h1 => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  
  static TextStyle get h2 => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static TextStyle get h3 => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static TextStyle get body1 => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );
  
  static TextStyle get body2 => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );
  
  static TextStyle get caption => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );
  
  static TextStyle get button => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.surface,
  );
}
```

### 5.3 Spacing

**File:** `lib/core/theme/spacing.dart`

```dart
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}
```

### 5.4 Theme Configuration

**File:** `lib/core/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';
import 'spacing.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        background: AppColors.background,
        error: AppColors.error,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.h1,
        displayMedium: AppTypography.h2,
        displaySmall: AppTypography.h3,
        bodyLarge: AppTypography.body1,
        bodyMedium: AppTypography.body2,
        labelLarge: AppTypography.button,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTypography.h3,
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
```

---

## 6) Reusable UI Widgets

### 6.1 AppButton

**File:** `lib/shared/widgets/app_button.dart`

**Features:**
- Primary and secondary variants
- Loading state
- Disabled state
- Full width option
- Icon support

**Usage:**
```dart
AppButton(
  text: 'Sign In',
  onPressed: () {},
  variant: ButtonVariant.primary,
  isLoading: false,
  isFullWidth: true,
)
```

### 6.2 AppTextField

**File:** `lib/shared/widgets/app_text_field.dart`

**Features:**
- Label and hint text
- Error message display
- Icon prefix/suffix
- Password visibility toggle
- Validation support

**Usage:**
```dart
AppTextField(
  label: 'Email',
  hint: 'Enter your email',
  controller: emailController,
  keyboardType: TextInputType.emailAddress,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
)
```

### 6.3 AppCard

**File:** `lib/shared/widgets/app_card.dart`

**Features:**
- Consistent padding and elevation
- Optional header
- Optional actions
- Clickable variant

### 6.4 LoadingIndicator

**File:** `lib/shared/widgets/loading_indicator.dart`

**Features:**
- Full screen overlay
- Inline spinner
- Custom message

### 6.5 ErrorMessage

**File:** `lib/shared/widgets/error_message.dart`

**Features:**
- Error icon
- Error message text
- Retry button option

---

## 7) Navigation & Routing

### 7.1 Route Structure

**File:** `lib/core/routing/route_names.dart`

```dart
class RouteNames {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String orgSelection = '/org-selection';
  static const String orgCreate = '/org-create';
  static const String home = '/home';
}
```

### 7.2 App Router

**File:** `lib/core/routing/app_router.dart`

- Define all routes
- Handle route guards (auth required, org required)
- Handle deep linking (future)

### 7.3 App Shell

**File:** `lib/shared/layouts/app_shell.dart`

**Features:**
- Bottom navigation bar (for mobile)
- Drawer navigation (for tablet/desktop)
- App bar with user menu
- Organization switcher
- Responsive layout

---

## 8) Firebase Auth Integration

### 8.1 Auth Service

**File:** `lib/services/auth_service.dart`

**Methods:**
- `signInWithEmailAndPassword(email, password)`
- `signUpWithEmailAndPassword(email, password)`
- `signOut()`
- `sendPasswordResetEmail(email)`
- `getCurrentUser()`
- `onAuthStateChanged()` (stream)

**Implementation:**
- Wrap Firebase Auth SDK
- Handle errors consistently
- Return standardized response format

### 8.2 Auth Screens

**Login Screen:**
- Email/password fields
- "Forgot password?" link
- "Sign up" link
- Sign in button
- Error message display

**Signup Screen:**
- Email field
- Password field
- Confirm password field
- Terms acceptance checkbox
- Sign up button
- "Already have account?" link

**Forgot Password Screen:**
- Email field
- Send reset email button
- Back to login link

---

## 9) Organization Selection/Gate

### 9.1 Org Selection Screen

**Purpose:** Allow user to select which organization to work with (if they're a member of multiple orgs)

**Features:**
- List of user's organizations
- "Create New Organization" button
- Organization card showing:
  - Org name
  - User's role
  - Plan tier
  - Member count (future)

**Implementation:**
- Call `member.getMyMembership` for each org (or create a new endpoint to list all memberships)
- Display orgs in a scrollable list
- On selection, store selected orgId in state/local storage
- Navigate to home screen

### 9.2 Org Create Screen

**Purpose:** Allow user to create a new organization

**Features:**
- Organization name field
- Description field (optional)
- Create button
- Cancel button

**Implementation:**
- Call `org.create` Cloud Function
- On success, navigate to org selection or home
- Handle errors (validation, etc.)

### 9.3 Org Gate Logic

**Flow:**
1. User authenticates
2. Check if user has any org memberships
3. If no memberships → Show org create screen
4. If one membership → Auto-select and go to home
5. If multiple memberships → Show org selection screen
6. Store selected orgId in app state
7. All subsequent API calls include orgId

---

## 10) State Management

### 10.1 Choose State Management Solution

**Options:**
- **Provider** (recommended for MVP): Simple, built-in Flutter support
- **Riverpod**: Type-safe, compile-time safety
- **Bloc**: Event-driven, good for complex flows

**Recommendation:** Start with Provider for simplicity, can migrate later if needed.

### 10.2 Required State Providers

- `AuthProvider` - Current user, auth state
- `OrgProvider` - Selected organization, org list
- `ThemeProvider` - Theme mode (light/dark - future)

---

## 11) Implementation Checklist

### 11.1 Project Setup
- [ ] Create Flutter project
- [ ] Configure Firebase (add `google-services.json` for Android, `GoogleService-Info.plist` for iOS)
- [ ] Add dependencies to `pubspec.yaml`
- [ ] Run `flutter pub get`

### 11.2 Theme System
- [ ] Create `colors.dart` with color palette
- [ ] Create `typography.dart` with text styles
- [ ] Create `spacing.dart` with spacing constants
- [ ] Create `app_theme.dart` with ThemeData
- [ ] Apply theme in `main.dart`

### 11.3 Reusable Widgets
- [ ] Create `AppButton` widget
- [ ] Create `AppTextField` widget
- [ ] Create `AppCard` widget
- [ ] Create `AppAppBar` widget
- [ ] Create `LoadingIndicator` widget
- [ ] Create `ErrorMessage` widget

### 11.4 Navigation
- [ ] Create route names constants
- [ ] Set up `AppRouter` with all routes
- [ ] Create `AppShell` layout
- [ ] Implement route guards

### 11.5 Auth Integration
- [ ] Create `AuthService` class
- [ ] Implement login screen
- [ ] Implement signup screen
- [ ] Implement forgot password screen
- [ ] Test auth flow end-to-end

### 11.6 Organization Gate
- [ ] Create org selection screen
- [ ] Create org create screen
- [ ] Implement org gate logic
- [ ] Store selected orgId in state
- [ ] Test org selection flow

### 11.7 State Management
- [ ] Set up Provider/Riverpod/Bloc
- [ ] Create `AuthProvider`
- [ ] Create `OrgProvider`
- [ ] Wire up providers in app

### 11.8 Testing
- [ ] Test login flow
- [ ] Test signup flow
- [ ] Test password reset flow
- [ ] Test org selection flow
- [ ] Test org creation flow
- [ ] Test navigation between screens
- [ ] Test responsive layout (mobile/tablet)

---

## 12) Dependencies

**External Services:**
- Firebase Authentication (required) - from Slice 0
- Firebase Cloud Functions (required) - for `org.create`, `org.join`, `member.getMyMembership`

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Required (org creation, org joining, membership retrieval)

**No Dependencies on:**
- Slice 2+ (Case Management, Client Management, etc.)

---

## 13) Estimated Effort

**Complexity:** Medium-High  
**Estimated Days:** 10-15 days  
**Dependencies:** Slice 0 ✅

**Breakdown:**
- Flutter project setup: 1 day
- Theme system: 2 days
- Reusable widgets: 3-4 days
- Navigation setup: 2 days
- Auth integration: 2-3 days
- Org selection/gate: 2 days
- State management: 1-2 days
- Testing & polish: 2-3 days

---

## 14) Success Criteria

**Slice 1 is complete when:**
- ✅ Flutter app runs on iOS and Android
- ✅ Theme system is implemented and consistent
- ✅ All reusable widgets are created and documented
- ✅ Navigation works between all screens
- ✅ Firebase Auth integration works (login, signup, logout, password reset)
- ✅ Organization selection/gate works
- ✅ User can create an organization
- ✅ Selected orgId is stored and accessible throughout app
- ✅ Loading states and error handling are implemented
- ✅ App is responsive (mobile and tablet layouts)
- ✅ Code follows Flutter best practices
- ✅ No business logic in UI (all API calls are in services)

---

END OF BUILD CARD
