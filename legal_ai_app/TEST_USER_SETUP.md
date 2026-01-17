# Test User Setup

## Test Credentials

- **Email**: test-17jan@test.com
- **Password**: 123456

## Step 1: Create User in Firebase Console

1. Go to Firebase Console:
   https://console.firebase.google.com/project/legal-ai-app-1203e/authentication/users

2. Click **"Add user"** button

3. Enter:
   - **Email**: `test-17jan@test.com`
   - **Password**: `123456`
   - **Disable email verification** (for testing)

4. Click **"Add user"**

## Step 2: Enable Email/Password Authentication

If not already enabled:

1. Go to: https://console.firebase.google.com/project/legal-ai-app-1203e/authentication/providers

2. Click on **"Email/Password"**

3. Enable the first toggle (Email/Password)

4. Click **"Save"**

## Step 3: Test Login

1. Run the app:
   ```cmd
   flutter run -d chrome
   ```

2. On the login screen, enter:
   - **Email**: test-17jan@test.com
   - **Password**: 123456

3. Click **"Sign In"**

4. You should be redirected to the organization selection screen.

## Alternative: Create User via App

If you prefer to create the user through the app:

1. Run the app: `flutter run -d chrome`
2. Click **"Sign Up"** on the login screen
3. Enter:
   - **Email**: test-17jan@test.com
   - **Password**: 123456
4. Click **"Sign Up"**
5. The user will be created automatically
6. Then you can log in with the same credentials

## Troubleshooting

### "User not found"
- Make sure the user was created in Firebase Console
- Check that Email/Password authentication is enabled

### "Invalid password"
- Verify the password is exactly: `123456`
- Try resetting the password in Firebase Console

### "Network error"
- Check your internet connection
- Verify Firebase project is active
