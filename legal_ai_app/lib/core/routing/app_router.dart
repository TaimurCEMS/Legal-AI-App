import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/password_reset_screen.dart';
import '../../features/home/screens/org_selection_screen.dart';
import '../../features/home/screens/org_create_screen.dart';
import '../../features/home/widgets/app_shell.dart';
import '../../features/cases/screens/case_list_screen.dart';
import '../../features/cases/screens/case_create_screen.dart';
import '../../features/cases/screens/case_details_screen.dart';
import '../../features/clients/screens/client_list_screen.dart';
import '../../features/clients/screens/client_create_screen.dart';
import '../../features/clients/screens/client_details_screen.dart';
import '../../features/documents/screens/document_list_screen.dart';
import '../../features/documents/screens/document_upload_screen.dart';
import '../../features/documents/screens/document_details_screen.dart';
import '../../features/tasks/screens/task_list_screen.dart';
import '../../features/tasks/screens/task_create_screen.dart';
import '../../features/tasks/screens/task_details_screen.dart';
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/calendar/screens/event_form_screen.dart';
import '../../features/calendar/screens/event_details_screen.dart';
import '../../features/notes/screens/note_list_screen.dart';
import '../../features/notes/screens/note_form_screen.dart';
import '../../features/notes/screens/note_details_screen.dart';
import '../../features/home/screens/settings_screen.dart';
import '../../features/home/screens/member_management_screen.dart';

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
      GoRoute(
        path: RouteNames.caseList,
        builder: (context, state) => const CaseListScreen(),
      ),
      GoRoute(
        path: RouteNames.caseCreate,
        builder: (context, state) => const CaseCreateScreen(),
      ),
      GoRoute(
        path: RouteNames.caseDetails,
        builder: (context, state) {
          final caseId = state.extra as String? ??
              (state.uri.queryParameters['caseId'] ?? '');
          return CaseDetailsScreen(caseId: caseId);
        },
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.memberManagement,
        builder: (context, state) => const MemberManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.clientList,
        builder: (context, state) => const ClientListScreen(),
      ),
      GoRoute(
        path: RouteNames.clientCreate,
        builder: (context, state) => const ClientCreateScreen(),
      ),
      GoRoute(
        path: RouteNames.clientDetails,
        builder: (context, state) {
          final clientId = state.extra as String? ??
              (state.uri.queryParameters['clientId'] ?? '');
          return ClientDetailsScreen(clientId: clientId);
        },
      ),
      GoRoute(
        path: RouteNames.documentList,
        builder: (context, state) => const DocumentListScreen(),
      ),
      GoRoute(
        path: RouteNames.documentUpload,
        builder: (context, state) {
          final caseId = state.uri.queryParameters['caseId'];
          return DocumentUploadScreen(caseId: caseId);
        },
      ),
      GoRoute(
        path: '${RouteNames.documentDetails}/:documentId',
        builder: (context, state) {
          final documentId = state.pathParameters['documentId'] ?? '';
          return DocumentDetailsScreen(documentId: documentId);
        },
      ),
      GoRoute(
        path: RouteNames.taskList,
        builder: (context, state) => const TaskListScreen(),
      ),
      GoRoute(
        path: RouteNames.taskCreate,
        builder: (context, state) {
          final caseId = state.uri.queryParameters['caseId'];
          return TaskCreateScreen(caseId: caseId);
        },
      ),
      GoRoute(
        path: RouteNames.taskDetails,
        builder: (context, state) {
          final taskId = state.extra as String? ??
              (state.uri.queryParameters['taskId'] ?? '');
          return TaskDetailsScreen(taskId: taskId);
        },
      ),
      GoRoute(
        path: RouteNames.calendar,
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: RouteNames.eventCreate,
        builder: (context, state) {
          final dateStr = state.uri.queryParameters['date'];
          DateTime? prefilledDate;
          if (dateStr != null && dateStr.isNotEmpty) {
            try {
              prefilledDate = DateTime.parse(dateStr);
            } catch (_) {
              // Invalid date format, ignore
            }
          }
          return EventFormScreen(prefilledDate: prefilledDate);
        },
      ),
      GoRoute(
        path: RouteNames.eventDetails,
        builder: (context, state) {
          final eventId = state.extra as String? ??
              (state.uri.queryParameters['eventId'] ?? '');
          return EventDetailsScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: RouteNames.eventEdit,
        builder: (context, state) {
          final eventId = state.extra as String? ??
              (state.uri.queryParameters['eventId'] ?? '');
          return EventFormScreen(eventId: eventId);
        },
      ),
      // Note routes
      GoRoute(
        path: RouteNames.noteList,
        builder: (context, state) {
          final caseId = state.uri.queryParameters['caseId'];
          final caseName = state.uri.queryParameters['caseName'];
          return NoteListScreen(caseId: caseId, caseName: caseName);
        },
      ),
      GoRoute(
        path: RouteNames.noteCreate,
        builder: (context, state) {
          final caseId = state.uri.queryParameters['caseId'];
          final caseName = state.uri.queryParameters['caseName'];
          return NoteFormScreen(caseId: caseId, caseName: caseName);
        },
      ),
      GoRoute(
        path: '${RouteNames.noteDetails}/:noteId',
        builder: (context, state) {
          final noteId = state.pathParameters['noteId'] ?? '';
          return NoteDetailsScreen(noteId: noteId);
        },
      ),
      GoRoute(
        path: '${RouteNames.noteEdit}/:noteId',
        builder: (context, state) {
          final noteId = state.pathParameters['noteId'] ?? '';
          return NoteFormScreen(noteId: noteId);
        },
      ),
    ],
  );
}
