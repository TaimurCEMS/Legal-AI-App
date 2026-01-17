# Firebase Setup Guide

## Prerequisites
- Firebase project created
- Firebase CLI installed (optional, for `flutterfire configure`)

## Step 1: Configure Firebase for Flutter

### Option A: Using FlutterFire CLI (Recommended)

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Configure Firebase:
   ```bash
   flutterfire configure
   ```
   
   This will:
   - Ask you to select your Firebase project
   - Generate `lib/firebase_options.dart` with your project config
   - Configure all platforms (web, iOS, Android)

### Option B: Manual Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create a new one)
3. Go to Project Settings → General
4. Scroll down to "Your apps" section
5. Click the web icon (`</>`) to add a web app
6. Register your app with a nickname
7. Copy the Firebase configuration
8. Update `lib/firebase_options.dart` with your config

## Step 2: Enable Email/Password Authentication

1. Go to Firebase Console → Authentication
2. Click "Get Started" (if first time)
3. Go to "Sign-in method" tab
4. Click on "Email/Password"
5. Enable "Email/Password" (first toggle)
6. Click "Save"

## Step 3: Create a Test User

### Option A: Via Firebase Console

1. Go to Firebase Console → Authentication → Users
2. Click "Add user"
3. Enter email and password
4. Click "Add user"

### Option B: Via App Sign Up

1. Run the app: `flutter run -d chrome`
2. Click "Sign Up" on the login screen
3. Enter email and password
4. Click "Sign Up"
5. The user will be created automatically

## Step 4: Test Login

1. Run the app: `flutter run -d chrome`
2. On the login screen, enter:
   - **Email**: The email you created
   - **Password**: The password you set
3. Click "Sign In"
4. You should be redirected to the organization selection screen

## Troubleshooting

### "Firebase not configured" error
- Run `flutterfire configure` to set up Firebase

### "User not found" error
- Make sure Email/Password authentication is enabled in Firebase Console
- Create a user account first (via Console or Sign Up)

### "Network error"
- Check your internet connection
- Verify Firebase project is active
- Check Firebase Console for any service issues

### App crashes on startup
- Make sure `firebase_options.dart` is properly configured
- Run `flutter pub get` to ensure all dependencies are installed

## Next Steps

After login works:
1. Create an organization (via the app)
2. Test organization selection
3. Test other features
