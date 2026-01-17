import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/password_reset_screen.dart';
import '../../features/home/screens/org_selection_screen.dart';
import '../../features/home/screens/org_create_screen.dart';
import '../../features/home/widgets/app_shell.dart';

/// App router configuration
class AppRouter {
  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    initialLocation: RouteNames.splash,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const PasswordResetScreen(),
      ),
      GoRoute(
        path: RouteNames.orgSelection,
        builder: (context, state) => const OrgSelectionScreen(),
      ),
      GoRoute(
        path: RouteNames.orgCreate,
        builder: (context, state) => const OrgCreateScreen(),
      ),
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const AppShell(),
      ),
    ],
  );
}
