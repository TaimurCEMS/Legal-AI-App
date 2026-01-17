# Legal AI App - Flutter Frontend

Flutter application for the Legal AI App project.

## Setup

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Configure Firebase:
   ```bash
   flutterfire configure
   ```
   - Select your platforms (Android, iOS, Web)
   - Select project: `legal-ai-app-1203e`

3. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # App widget with providers
├── core/
│   ├── theme/                   # Theme system
│   ├── routing/                  # Navigation
│   ├── services/                # Backend services
│   └── models/                   # Data models
├── features/
│   ├── auth/                     # Authentication
│   ├── home/                     # Home & org management
│   └── common/                   # Shared widgets
```

## Features

- ✅ Theme system (colors, typography, spacing)
- ✅ Reusable UI widgets
- ✅ Firebase Auth integration
- ✅ Organization management
- ✅ Navigation shell
- ✅ State management (Provider)

## Dependencies

- Firebase Core & Auth
- Cloud Functions
- Provider (state management)
- Go Router (navigation)
