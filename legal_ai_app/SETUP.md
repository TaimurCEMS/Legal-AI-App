# Flutter App Setup Instructions

## Prerequisites

1. **Flutter SDK** (3.0.0 or higher)
   - Install from: https://flutter.dev/docs/get-started/install
   - Verify: `flutter doctor`

2. **Firebase CLI**
   - Install: `npm install -g firebase-tools`
   - Login: `firebase login`

3. **FlutterFire CLI**
   - Install: `dart pub global activate flutterfire_cli`
   - Add to PATH if needed

## Setup Steps

### 1. Install Dependencies

```bash
cd legal_ai_app
flutter pub get
```

### 2. Configure Firebase

```bash
flutterfire configure
```

**Configuration:**
- Select platforms: Android, iOS (and Web if testing locally)
- Select Firebase project: `legal-ai-app-1203e`
- Follow prompts to configure each platform

This will create:
- `lib/firebase_options.dart` (auto-generated)
- Platform-specific config files

### 3. Update main.dart

The `main.dart` file should automatically use `firebase_options.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

### 4. Run the App

**Android:**
```bash
flutter run
```

**iOS:**
```bash
flutter run -d ios
```

**Web:**
```bash
flutter run -d chrome
```

## Project Structure

```
legal_ai_app/
├── lib/
│   ├── main.dart              # Entry point
│   ├── app.dart               # App widget
│   ├── core/                  # Core functionality
│   │   ├── theme/             # Theme system
│   │   ├── routing/           # Navigation
│   │   ├── services/          # Backend services
│   │   └── models/            # Data models
│   └── features/              # Feature modules
│       ├── auth/              # Authentication
│       ├── home/              # Home & org management
│       └── common/            # Shared widgets
├── pubspec.yaml               # Dependencies
└── README.md                  # This file
```

## Testing

Run tests:
```bash
flutter test
```

## Building

**Android APK:**
```bash
flutter build apk
```

**iOS:**
```bash
flutter build ios
```

**Web:**
```bash
flutter build web
```

## Troubleshooting

### Firebase not initialized
- Ensure `flutterfire configure` completed successfully
- Check that `firebase_options.dart` exists
- Verify Firebase project ID matches: `legal-ai-app-1203e`

### Cloud Functions not working
- Ensure Firebase project is set correctly
- Check that Cloud Functions are deployed (Slice 0)
- Verify region matches: `us-central1`

### Build errors
- Run `flutter clean`
- Run `flutter pub get`
- Check Flutter version: `flutter --version`
