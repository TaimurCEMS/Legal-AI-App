import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_model.dart';

/// Auth provider for managing authentication state
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _init();
  }

  void _init() {
    _currentUser = _authService.currentUser;
    // Save user ID if user is already authenticated (e.g., on app restart)
    // But first verify it matches what's saved (to prevent cross-tab contamination)
    if (_currentUser != null) {
      SharedPreferences.getInstance().then((prefs) async {
        final savedUserId = prefs.getString('user_id');
        // Only save if it matches current user or is null (first time)
        // If different user ID is saved, clear it first (another tab logged in)
        if (savedUserId != null && savedUserId != _currentUser!.uid) {
          debugPrint('AuthProvider: Detected different user in storage. Clearing stale state.');
          await prefs.remove('user_id');
          await prefs.remove('selected_org_id');
          await prefs.remove('selected_org');
          await prefs.remove('user_org_ids');
        }
        await prefs.setString('user_id', _currentUser!.uid);
      });
    }
    _authService.authStateChanges.listen((user) async {
      final previousUser = _currentUser;
      _currentUser = user;
      
      // If user changed (not just logged out), clear all saved state
      if (previousUser != null && user != null && previousUser.uid != user.uid) {
        debugPrint('AuthProvider: User changed from ${previousUser.uid} to ${user.uid}. Clearing state.');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('selected_org_id');
        await prefs.remove('selected_org');
        await prefs.remove('user_org_ids');
      }
      
      // Save user ID whenever auth state changes
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final savedUserId = prefs.getString('user_id');
        // Verify saved user matches current user
        if (savedUserId != null && savedUserId != user.uid) {
          debugPrint('AuthProvider: Saved user ID mismatch. Clearing stale state.');
          await prefs.remove('selected_org_id');
          await prefs.remove('selected_org');
          await prefs.remove('user_org_ids');
        }
        await prefs.setString('user_id', user.uid);
      } else {
        // Clear user ID on logout
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_id');
        await prefs.remove('selected_org_id');
        await prefs.remove('selected_org');
        await prefs.remove('user_org_ids');
      }
      notifyListeners();
    });
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _currentUser = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user ID for org persistence
      if (_currentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _currentUser!.uid);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Log full error for debugging
      debugPrint('AuthProvider.signIn error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      
      // Extract more detailed error message
      String errorMsg = 'Login failed';
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('placeholder')) {
        errorMsg = 'Firebase not configured. Run: flutterfire configure';
      } else if (errorString.contains('user-not-found')) {
        errorMsg = 'No user found with this email address.';
      } else if (errorString.contains('wrong-password') || errorString.contains('invalid-credential')) {
        errorMsg = 'Incorrect password.';
      } else if (errorString.contains('network') || errorString.contains('failed')) {
        errorMsg = 'Network error. Check Firebase configuration.';
      } else if (errorString.contains('invalid-email')) {
        errorMsg = 'Invalid email address.';
      } else {
        errorMsg = e.toString();
      }
      
      _errorMessage = errorMsg;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _currentUser = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user ID for org persistence
      if (_currentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _currentUser!.uid);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.sendPasswordResetEmail(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    // Clear saved user ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
