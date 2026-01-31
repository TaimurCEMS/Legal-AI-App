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
import '../../features/drafting/screens/case_drafting_screen.dart';
import '../../features/drafting/screens/draft_editor_screen.dart';
import '../../features/audit/screens/audit_trail_screen.dart';
import '../../features/admin/screens/admin_settings_screen.dart';
import '../../features/admin/screens/invitation_management_screen.dart';
import '../../features/admin/screens/organization_settings_screen.dart';
import '../../features/admin/screens/organization_export_screen.dart';
import '../../features/admin/screens/organization_dashboard_screen.dart';
import '../../features/admin/screens/member_profile_screen.dart';
import '../../features/notifications/screens/notification_list_screen.dart';
import '../../features/notifications/screens/notification_preferences_screen.dart';
import '../../features/activity_feed/screens/activity_feed_screen.dart';

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
        path: RouteNames.auditTrail,
        builder: (context, state) => const AuditTrailScreen(),
      ),
      // Slice 15 Admin
      GoRoute(
        path: RouteNames.adminSettings,
        builder: (context, state) => const AdminSettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.invitationManagement,
        builder: (context, state) => const InvitationManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.organizationSettings,
        builder: (context, state) => const OrganizationSettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.organizationExport,
        builder: (context, state) => const OrganizationExportScreen(),
      ),
      GoRoute(
        path: RouteNames.organizationDashboard,
        builder: (context, state) => const OrganizationDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.memberProfile,
        builder: (context, state) {
          final memberUid = state.uri.queryParameters['memberUid'];
          return MemberProfileScreen(memberUid: memberUid);
        },
      ),
      GoRoute(
        name: 'notifications',
        path: RouteNames.notifications,
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        name: 'notificationPreferences',
        path: RouteNames.notificationPreferences,
        builder: (context, state) => const NotificationPreferencesScreen(),
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

      // Drafting routes (Slice 9)
      GoRoute(
        path: RouteNames.drafts,
        builder: (context, state) {
          final caseId = state.uri.queryParameters['caseId'] ?? '';
          final caseTitle = state.uri.queryParameters['caseTitle'] ?? 'Case';
          return CaseDraftingScreen(caseId: caseId, caseTitle: caseTitle);
        },
      ),
      GoRoute(
        path: '${RouteNames.draftEditor}/:draftId',
        builder: (context, state) {
          final draftId = state.pathParameters['draftId'] ?? '';
          final caseId = state.uri.queryParameters['caseId'] ?? '';
          final caseTitle = state.uri.queryParameters['caseTitle'] ?? 'Case';
          return DraftEditorScreen(draftId: draftId, caseId: caseId, caseTitle: caseTitle);
        },
      ),

      // Slice 16 Activity Feed
      GoRoute(
        path: RouteNames.activityFeed,
        builder: (context, state) {
          final matterId = state.uri.queryParameters['matterId'];
          return ActivityFeedScreen(matterId: matterId);
        },
      ),
    ],
  );
}
