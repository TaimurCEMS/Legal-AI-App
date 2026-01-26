import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/event_model.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/colors.dart';
import '../../home/providers/org_provider.dart';
import '../providers/event_provider.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/error_message.dart';

/// Event Details Screen - View event information (Slice 7)
class EventDetailsScreen extends StatefulWidget {
  final String eventId;

  const EventDetailsScreen({super.key, required this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvent();
    });
  }

  void _loadEvent() {
    final orgProvider = context.read<OrgProvider>();
    final eventProvider = context.read<EventProvider>();

    if (orgProvider.selectedOrg == null) return;

    eventProvider.loadEventDetails(
      org: orgProvider.selectedOrg!,
      eventId: widget.eventId,
    );
  }

  void _navigateToEdit() async {
    await context.push('${RouteNames.eventEdit}?eventId=${widget.eventId}');
    if (mounted) {
      _loadEvent();
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Are you sure you want to delete this event? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final orgProvider = context.read<OrgProvider>();
      final eventProvider = context.read<EventProvider>();

      if (orgProvider.selectedOrg == null) return;

      final success = await eventProvider.deleteEvent(
        org: orgProvider.selectedOrg!,
        eventId: widget.eventId,
      );

      if (success && mounted) {
        context.pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eventProvider.errorMessage ?? 'Failed to delete event'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(EventStatus newStatus) async {
    final orgProvider = context.read<OrgProvider>();
    final eventProvider = context.read<EventProvider>();

    if (orgProvider.selectedOrg == null) return;

    final success = await eventProvider.updateEvent(
      org: orgProvider.selectedOrg!,
      eventId: widget.eventId,
      status: newStatus,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event marked as ${newStatus.displayName.toLowerCase()}'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eventProvider.errorMessage ?? 'Failed to update status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        final event = eventProvider.selectedEvent;
        final isLoading = eventProvider.isLoading;
        final hasError = eventProvider.hasError && event == null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Event Details'),
            actions: [
              if (event != null) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _navigateToEdit,
                  tooltip: 'Edit',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'complete':
                        _updateStatus(EventStatus.completed);
                        break;
                      case 'cancel':
                        _updateStatus(EventStatus.cancelled);
                        break;
                      case 'reschedule':
                        _updateStatus(EventStatus.scheduled);
                        break;
                      case 'delete':
                        _showDeleteConfirmation();
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String>>[];
                    
                    if (event.status == EventStatus.scheduled) {
                      items.add(const PopupMenuItem(
                        value: 'complete',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 20),
                            SizedBox(width: 8),
                            Text('Mark Complete'),
                          ],
                        ),
                      ));
                      items.add(const PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Cancel Event'),
                          ],
                        ),
                      ));
                    } else {
                      items.add(const PopupMenuItem(
                        value: 'reschedule',
                        child: Row(
                          children: [
                            Icon(Icons.schedule, size: 20),
                            SizedBox(width: 8),
                            Text('Reschedule'),
                          ],
                        ),
                      ));
                    }
                    
                    items.add(const PopupMenuDivider());
                    items.add(const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ));
                    
                    return items;
                  },
                ),
              ],
            ],
          ),
          body: isLoading && event == null
              ? const Center(child: LoadingSpinner())
              : hasError
                  ? ErrorMessage(
                      message: eventProvider.errorMessage ?? 'Failed to load event',
                      onRetry: _loadEvent,
                    )
                  : event == null
                      ? const Center(child: Text('Event not found'))
                      : _buildContent(event),
        );
      },
    );
  }

  Widget _buildContent(EventModel event) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and status
          _buildHeader(event),
          SizedBox(height: AppSpacing.lg),

          // Date and time
          _buildSection(
            icon: Icons.calendar_today,
            title: 'Date & Time',
            child: _buildDateTimeInfo(event),
          ),

          // Location
          if (event.location != null && event.location!.isNotEmpty)
            _buildSection(
              icon: Icons.location_on_outlined,
              title: 'Location',
              child: Text(event.location!),
            ),

          // Event type
          _buildSection(
            icon: Icons.category_outlined,
            title: 'Type',
            child: _buildEventTypeChip(event.eventType),
          ),

          // Priority
          _buildSection(
            icon: Icons.flag_outlined,
            title: 'Priority',
            child: _buildPriorityChip(event.priority),
          ),

          // Visibility
          _buildSection(
            icon: Icons.visibility_outlined,
            title: 'Visibility',
            child: Text(event.visibility.displayName),
          ),

          // Case link
          if (event.caseId != null)
            _buildSection(
              icon: Icons.folder_outlined,
              title: 'Linked Case',
              child: Row(
                children: [
                  Expanded(
                    child: Text(event.caseName ?? event.caseId!),
                  ),
                  if (event.hasCaseWarning) ...[
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      event.caseStatus ?? '',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),

          // Reminders
          if (event.reminders.isNotEmpty)
            _buildSection(
              icon: Icons.notifications_outlined,
              title: 'Reminders',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: event.reminders
                    .map((r) => Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text('• ${r.displayName}'),
                        ))
                    .toList(),
              ),
            ),

          // Recurrence
          if (event.recurrence != null)
            _buildSection(
              icon: Icons.repeat,
              title: 'Recurrence',
              child: Text(event.recurrence!.displayName),
            ),

          // Description
          if (event.description != null && event.description!.isNotEmpty)
            _buildSection(
              icon: Icons.description_outlined,
              title: 'Description',
              child: Text(event.description!),
            ),

          // Notes
          if (event.notes != null && event.notes!.isNotEmpty)
            _buildSection(
              icon: Icons.note_outlined,
              title: 'Notes',
              child: Text(event.notes!),
            ),

          // Metadata
          SizedBox(height: AppSpacing.lg),
          _buildMetadata(event),
        ],
      ),
    );
  }

  Widget _buildHeader(EventModel event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: event.status == EventStatus.cancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        _buildStatusBadge(event.status),
      ],
    );
  }

  Widget _buildStatusBadge(EventStatus status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case EventStatus.scheduled:
        color = Colors.blue;
        icon = Icons.schedule;
        break;
      case EventStatus.completed:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case EventStatus.cancelled:
        color = Colors.red;
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeInfo(EventModel event) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateFormat.format(event.startDateTime),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (!event.allDay) ...[
          SizedBox(height: 4),
          Text(
            event.endDateTime != null
                ? '${timeFormat.format(event.startDateTime)} - ${timeFormat.format(event.endDateTime!)}'
                : timeFormat.format(event.startDateTime),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
        ] else
          Text(
            'All day',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
        if (event.duration != null && !event.allDay)
          Text(
            'Duration: ${_formatDuration(event.duration!)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} minutes';
    } else if (duration.inHours < 24) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes == 0) {
        return '$hours hour${hours == 1 ? '' : 's'}';
      }
      return '$hours hour${hours == 1 ? '' : 's'} $minutes minutes';
    } else {
      final days = duration.inDays;
      return '$days day${days == 1 ? '' : 's'}';
    }
  }

  Widget _buildEventTypeChip(EventType type) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getEventTypeColor(type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(
          color: _getEventTypeColor(type),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(EventPriority priority) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getPriorityColor(priority).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        priority.displayName,
        style: TextStyle(
          color: _getPriorityColor(priority),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMetadata(EventModel event) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Created: ${dateFormat.format(event.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          if (event.updatedAt != event.createdAt) ...[
            SizedBox(height: 4),
            Text(
              'Updated: ${dateFormat.format(event.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getPriorityColor(EventPriority priority) {
    switch (priority) {
      case EventPriority.critical:
        return Colors.red;
      case EventPriority.high:
        return Colors.orange;
      case EventPriority.medium:
        return Colors.blue;
      case EventPriority.low:
        return Colors.grey;
    }
  }

  Color _getEventTypeColor(EventType type) {
    switch (type) {
      case EventType.courtDate:
        return Colors.red;
      case EventType.hearing:
        return Colors.orange;
      case EventType.filingDeadline:
        return Colors.purple;
      case EventType.statuteLimitation:
        return Colors.red.shade900;
      case EventType.meeting:
        return Colors.blue;
      case EventType.consultation:
        return Colors.teal;
      case EventType.deposition:
        return Colors.indigo;
      case EventType.mediation:
        return Colors.green;
      case EventType.arbitration:
        return Colors.deepPurple;
      case EventType.other:
        return Colors.grey;
    }
  }
}
