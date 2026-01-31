import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/event_model.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../home/providers/org_provider.dart';
import '../providers/event_provider.dart';
import '../../common/widgets/loading/loading_spinner.dart';
import '../../common/widgets/empty_state/empty_state_widget.dart';
import '../../common/widgets/error_message.dart';

/// Calendar view modes
enum CalendarViewMode {
  day,
  week,
  month,
  agenda;

  String get label {
    switch (this) {
      case CalendarViewMode.day:
        return 'Day';
      case CalendarViewMode.week:
        return 'Week';
      case CalendarViewMode.month:
        return 'Month';
      case CalendarViewMode.agenda:
        return 'Agenda';
    }
  }

  IconData get icon {
    switch (this) {
      case CalendarViewMode.day:
        return Icons.view_day;
      case CalendarViewMode.week:
        return Icons.view_week;
      case CalendarViewMode.month:
        return Icons.calendar_view_month;
      case CalendarViewMode.agenda:
        return Icons.view_agenda;
    }
  }
}

/// Calendar Screen - Main list view for events (Slice 7)
class CalendarScreen extends StatefulWidget {
  /// When used in app shell, [selectedTabIndex] and [tabIndex] trigger load when this tab becomes visible.
  const CalendarScreen({
    super.key,
    this.selectedTabIndex,
    this.tabIndex,
  });

  final int? selectedTabIndex;
  final int? tabIndex;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final TextEditingController _searchController = TextEditingController();
  EventType? _selectedEventType;
  EventStatus? _selectedStatus;
  DateTime _selectedDate = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.month;
  
  String? _lastLoadedOrgId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load if: standalone mode (both null) OR visible in shell (both non-null and equal)
      final isStandalone = widget.selectedTabIndex == null && widget.tabIndex == null;
      final isVisibleInShell = widget.selectedTabIndex != null &&
          widget.tabIndex != null &&
          widget.selectedTabIndex == widget.tabIndex;
      if (isStandalone || isVisibleInShell) {
        _loadEvents();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nowVisible = widget.selectedTabIndex != null &&
        widget.tabIndex != null &&
        widget.selectedTabIndex == widget.tabIndex;
    final wasVisible = oldWidget.selectedTabIndex != null &&
        oldWidget.tabIndex != null &&
        oldWidget.selectedTabIndex == oldWidget.tabIndex;
    
    // Load when we become visible
    if (nowVisible && !wasVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadEvents(refresh: true);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadEvents({bool refresh = false}) {
    final orgProvider = context.read<OrgProvider>();
    final eventProvider = context.read<EventProvider>();
    
    if (orgProvider.selectedOrg == null) return;
    
    // Calculate date range based on view mode
    DateTime startDate;
    DateTime endDate;
    
    switch (_viewMode) {
      case CalendarViewMode.day:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = startDate.add(const Duration(days: 1));
        break;
      case CalendarViewMode.week:
        // Start from Monday of the selected week
        final weekday = _selectedDate.weekday;
        startDate = _selectedDate.subtract(Duration(days: weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 7));
        break;
      case CalendarViewMode.month:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        break;
      case CalendarViewMode.agenda:
        // Show next 30 days for agenda view
        startDate = DateTime.now();
        endDate = startDate.add(const Duration(days: 30));
        break;
    }
    
    eventProvider.loadEvents(
      org: orgProvider.selectedOrg!,
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      eventType: _selectedEventType,
      status: _selectedStatus,
      startDate: DateFormat('yyyy-MM-dd').format(startDate),
      endDate: DateFormat('yyyy-MM-dd').format(endDate),
      refresh: refresh,
    );
  }

  void _onSearchChanged(String value) {
    // Debounce search
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _searchController.text == value) {
        _loadEvents(refresh: true);
      }
    });
  }

  void _onEventTypeChanged(EventType? type) {
    setState(() {
      _selectedEventType = type;
    });
    _loadEvents(refresh: true);
  }

  void _onStatusChanged(EventStatus? status) {
    setState(() {
      _selectedStatus = status;
    });
    _loadEvents(refresh: true);
  }

  void _onDateNavigation(int delta) {
    setState(() {
      switch (_viewMode) {
        case CalendarViewMode.day:
          _selectedDate = _selectedDate.add(Duration(days: delta));
          break;
        case CalendarViewMode.week:
          _selectedDate = _selectedDate.add(Duration(days: delta * 7));
          break;
        case CalendarViewMode.month:
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
          break;
        case CalendarViewMode.agenda:
          // No navigation for agenda - it always shows upcoming 30 days
          return;
      }
    });
    _loadEvents(refresh: true);
  }

  void _onViewModeChanged(CalendarViewMode mode) {
    setState(() {
      _viewMode = mode;
      // Reset to today when changing view
      if (mode == CalendarViewMode.agenda) {
        _selectedDate = DateTime.now();
      }
    });
    _loadEvents(refresh: true);
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadEvents(refresh: true);
  }

  void _navigateToCreateEvent({DateTime? prefilledDate}) async {
    final route = prefilledDate != null
        ? '${RouteNames.eventCreate}?date=${prefilledDate.toIso8601String()}'
        : RouteNames.eventCreate;
    await context.push(route);
    if (mounted) {
      _loadEvents(refresh: true);
    }
  }

  void _navigateToEventDetails(EventModel event) async {
    await context.push('${RouteNames.eventDetails}?eventId=${event.eventId}');
    if (mounted) {
      _loadEvents(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>().selectedOrg;
    
    // Load if: standalone mode (both null) OR visible in shell (both non-null and equal)
    final isStandalone = widget.selectedTabIndex == null && widget.tabIndex == null;
    final isVisibleInShell = widget.selectedTabIndex != null &&
        widget.tabIndex != null &&
        widget.selectedTabIndex == widget.tabIndex;
    final shouldLoad = isStandalone || isVisibleInShell;
    
    if (shouldLoad && org != null && _lastLoadedOrgId != org.orgId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _lastLoadedOrgId = org.orgId;
          _loadEvents(refresh: true);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          // Today button
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today, size: 18),
            label: const Text('Today'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadEvents(refresh: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // View mode selector
          _buildViewModeSelector(),
          // Date navigation
          _buildDateNavigation(),
          // Search and filters
          _buildSearchAndFilters(),
          // Events list/calendar view
          Expanded(
            child: _buildCalendarContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateEvent,
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
    );
  }

  Widget _buildViewModeSelector() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: SegmentedButton<CalendarViewMode>(
        segments: CalendarViewMode.values.map((mode) {
          return ButtonSegment<CalendarViewMode>(
            value: mode,
            label: Text(mode.label),
            icon: Icon(mode.icon, size: 18),
          );
        }).toList(),
        selected: {_viewMode},
        onSelectionChanged: (Set<CalendarViewMode> selection) {
          _onViewModeChanged(selection.first);
        },
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildDateNavigation() {
    // For agenda view, show a static header
    if (_viewMode == CalendarViewMode.agenda) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Upcoming 30 Days',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );
    }

    // Format the date label based on view mode
    String dateLabel;
    switch (_viewMode) {
      case CalendarViewMode.day:
        dateLabel = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);
        break;
      case CalendarViewMode.week:
        final weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        if (weekStart.month == weekEnd.month) {
          dateLabel = '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('d, yyyy').format(weekEnd)}';
        } else {
          dateLabel = '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d, yyyy').format(weekEnd)}';
        }
        break;
      case CalendarViewMode.month:
        dateLabel = DateFormat('MMMM yyyy').format(_selectedDate);
        break;
      case CalendarViewMode.agenda:
        dateLabel = ''; // Handled above
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _onDateNavigation(-1),
            tooltip: 'Previous',
          ),
          Expanded(
            child: Text(
              dateLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _onDateNavigation(1),
            tooltip: 'Next',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search events...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadEvents(refresh: true);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          SizedBox(height: AppSpacing.sm),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Event type filter
                _buildFilterDropdown<EventType>(
                  value: _selectedEventType,
                  hint: 'All Types',
                  items: EventType.values,
                  getLabel: (e) => e.displayName,
                  onChanged: _onEventTypeChanged,
                ),
                SizedBox(width: AppSpacing.sm),
                // Status filter
                _buildFilterDropdown<EventStatus>(
                  value: _selectedStatus,
                  hint: 'All Status',
                  items: EventStatus.values,
                  getLabel: (e) => e.displayName,
                  onChanged: _onStatusChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) getLabel,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text(hint),
            ),
            ...items.map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(getLabel(item)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCalendarContent() {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, _) {
        if (eventProvider.isLoading && eventProvider.events.isEmpty) {
          return const Center(child: LoadingSpinner());
        }

        if (eventProvider.hasError && eventProvider.events.isEmpty) {
          return ErrorMessage(
            message: eventProvider.errorMessage ?? 'Failed to load events',
            onRetry: () => _loadEvents(refresh: true),
          );
        }

        // Build view based on mode
        switch (_viewMode) {
          case CalendarViewMode.day:
            return _buildDayView(eventProvider.events);
          case CalendarViewMode.week:
            return _buildWeekView(eventProvider.events);
          case CalendarViewMode.month:
            return _buildMonthView(eventProvider.events);
          case CalendarViewMode.agenda:
            return _buildAgendaView(eventProvider.events);
        }
      },
    );
  }

  Widget _buildDayView(List<EventModel> events) {
    if (events.isEmpty) {
      return _buildEmptyState();
    }

    // Sort events by time
    final sortedEvents = List<EventModel>.from(events)
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    return RefreshIndicator(
      onRefresh: () async => _loadEvents(refresh: true),
      child: ListView(
        padding: EdgeInsets.only(bottom: 80),
        children: [
          // Time slots header
          _buildTimeHeader(),
          // Events
          ...sortedEvents.map((event) => _buildDayEventCard(event)),
        ],
      ),
    );
  }

  Widget _buildTimeHeader() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: Colors.grey.shade600),
          SizedBox(width: AppSpacing.sm),
          Text(
            'Schedule',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayEventCard(EventModel event) {
    final timeFormat = DateFormat('h:mm a');
    final isNow = event.startDateTime.isBefore(DateTime.now()) &&
        (event.endDateTime?.isAfter(DateTime.now()) ?? true);

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: isNow ? AppColors.primary.withOpacity(0.05) : null,
      child: InkWell(
        onTap: () => _navigateToEventDetails(event),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time column
              SizedBox(
                width: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.allDay ? 'All day' : timeFormat.format(event.startDateTime),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isNow ? AppColors.primary : null,
                          ),
                    ),
                    if (!event.allDay && event.endDateTime != null)
                      Text(
                        timeFormat.format(event.endDateTime!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.md),
              // Priority indicator
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: _getPriorityColor(event.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: 4),
                    _buildEventMetaRow(event),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekView(List<EventModel> events) {
    // Get week dates - always show 7 days even if no events
    final weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final weekDates = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    // Group events by date
    final eventsByDate = <DateTime, List<EventModel>>{};
    for (final event in events) {
      final dateOnly = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      eventsByDate.putIfAbsent(dateOnly, () => []).add(event);
    }

    return RefreshIndicator(
      onRefresh: () async => _loadEvents(refresh: true),
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 80),
        itemCount: weekDates.length,
        itemBuilder: (context, index) {
          final date = weekDates[index];
          final dateOnly = DateTime(date.year, date.month, date.day);
          final dayEvents = eventsByDate[dateOnly] ?? [];
          final isToday = _isToday(date);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day header - clickable to add event
              _buildWeekDayHeader(date, isToday, dayEvents.length),
              // Events for this day
              if (dayEvents.isNotEmpty)
                ...dayEvents.map((event) => _buildCompactEventCard(event))
              else
                // Clickable empty area to create event
                InkWell(
                  onTap: () => _navigateToCreateEvent(prefilledDate: date),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, 
                             size: 16, 
                             color: Colors.grey.shade400),
                        SizedBox(width: AppSpacing.xs),
                        Text(
                          'Tap to add event',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (index < 6) Divider(height: 1),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWeekDayHeader(DateTime date, bool isToday, int eventCount) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      color: isToday ? AppColors.primary.withOpacity(0.05) : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                DateFormat('d').format(date),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.white : null,
                    ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE').format(date),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday ? AppColors.primary : null,
                    ),
              ),
              Text(
                DateFormat('MMM d').format(date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
          const Spacer(),
          // Add event button
          IconButton(
            icon: Icon(Icons.add, size: 20),
            onPressed: () => _navigateToCreateEvent(prefilledDate: date),
            tooltip: 'Add event',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          SizedBox(width: AppSpacing.xs),
          if (eventCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$eventCount event${eventCount > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactEventCard(EventModel event) {
    final timeFormat = DateFormat('h:mm a');

    return InkWell(
      onTap: () => _navigateToEventDetails(event),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            SizedBox(width: 48), // Indent under date
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: _getPriorityColor(event.priority),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Row(
                children: [
                  Text(
                    event.allDay ? 'All day' : timeFormat.format(event.startDateTime),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            _buildMiniTypeChip(event.eventType),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTypeChip(EventType type) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getEventTypeColor(type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.displayName.split(' ').first, // Just first word
        style: TextStyle(
          fontSize: 10,
          color: _getEventTypeColor(type),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMonthView(List<EventModel> events) {
    // Month view shows only the calendar grid (no events list below)
    // Use Agenda tab for list view
    return RefreshIndicator(
      onRefresh: () async => _loadEvents(refresh: true),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 80),
        child: _buildMonthCalendarGrid(events),
      ),
    );
  }

  Widget _buildMonthCalendarGrid(List<EventModel> events) {
    // Get first and last day of month
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    
    // Calculate start (Sunday before first day)
    final startOffset = firstDay.weekday % 7;
    final gridStart = firstDay.subtract(Duration(days: startOffset));
    
    // Group events by date
    final eventsByDate = <DateTime, List<EventModel>>{};
    for (final event in events) {
      final dateOnly = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      eventsByDate.putIfAbsent(dateOnly, () => []).add(event);
    }

    return Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: AppSpacing.xs),
          // Calendar grid (6 weeks max)
          ...List.generate(6, (weekIndex) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (dayIndex) {
                final date = gridStart.add(Duration(days: weekIndex * 7 + dayIndex));
                final isCurrentMonth = date.month == _selectedDate.month;
                final isToday = _isToday(date);
                final dateOnly = DateTime(date.year, date.month, date.day);
                final dayEvents = eventsByDate[dateOnly] ?? [];

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (dayEvents.isEmpty) {
                        // No events - create new event for this date
                        _navigateToCreateEvent(prefilledDate: date);
                      } else {
                        // Has events - go to day view
                        setState(() {
                          _selectedDate = date;
                          _viewMode = CalendarViewMode.day;
                        });
                        _loadEvents(refresh: true);
                      }
                    },
                    onDoubleTap: () {
                      // Double tap always creates new event
                      _navigateToCreateEvent(prefilledDate: date);
                    },
                    child: Container(
                      height: 55,
                      margin: EdgeInsets.all(1),
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isToday ? AppColors.primary.withOpacity(0.1) : null,
                        border: Border.all(
                          color: isToday ? AppColors.primary : Colors.grey.shade200,
                          width: isToday ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Date number
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isToday ? AppColors.primary : null,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${date.day}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: isToday
                                          ? Colors.white
                                          : isCurrentMonth
                                              ? null
                                              : Colors.grey.shade400,
                                      fontWeight: isToday ? FontWeight.bold : null,
                                    ),
                              ),
                            ),
                          ),
                          // Event titles (up to 2)
                          ...dayEvents.take(2).map((event) => Container(
                                margin: const EdgeInsets.only(top: 1),
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: _getEventTypeColor(event.eventType).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  event.title,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: _getEventTypeColor(event.eventType),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                          // Show "+N more" if there are more events
                          if (dayEvents.length > 2)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                '+${dayEvents.length - 2}',
                                style: TextStyle(
                                  fontSize: 7,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAgendaView(List<EventModel> events) {
    if (events.isEmpty) {
      return _buildEmptyState();
    }

    return _buildAgendaEventsList(events);
  }

  Widget _buildAgendaEventsList(List<EventModel> events) {
    // Group events by date
    final eventsByDate = <DateTime, List<EventModel>>{};
    for (final event in events) {
      final dateOnly = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      eventsByDate.putIfAbsent(dateOnly, () => []).add(event);
    }

    final sortedDates = eventsByDate.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: () async => _loadEvents(refresh: true),
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 80),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final dayEvents = eventsByDate[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(date),
              ...dayEvents.map((event) => _buildEventCard(event)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.calendar_today_outlined,
      title: 'No Events',
      message: 'No events found for this period.\nTap + to create one.',
      actionLabel: 'Create Event',
      onAction: _navigateToCreateEvent,
    );
  }

  Widget _buildEventMetaRow(EventModel event) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getEventTypeColor(event.eventType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            event.eventType.displayName,
            style: TextStyle(
              fontSize: 11,
              color: _getEventTypeColor(event.eventType),
            ),
          ),
        ),
        if (event.location != null && event.location!.isNotEmpty) ...[
          SizedBox(width: AppSpacing.sm),
          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
          SizedBox(width: 2),
          Expanded(
            child: Text(
              event.location!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    String dateLabel;
    if (date == today) {
      dateLabel = 'Today';
    } else if (date == tomorrow) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = DateFormat('EEEE, MMMM d').format(date);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        dateLabel,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: date == today ? AppColors.primary : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildEventCard(EventModel event) {
    final timeFormat = DateFormat('h:mm a');
    
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        onTap: () => _navigateToEventDetails(event),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority indicator
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: _getPriorityColor(event.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: event.status == EventStatus.cancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (event.status != EventStatus.scheduled)
                          _buildStatusChip(event.status),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xs),
                    // Time and type
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 4),
                        Text(
                          event.allDay
                              ? 'All day'
                              : timeFormat.format(event.startDateTime),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getEventTypeColor(event.eventType).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event.eventType.displayName,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: _getEventTypeColor(event.eventType),
                                ),
                          ),
                        ),
                      ],
                    ),
                    // Location if present
                    if (event.location != null && event.location!.isNotEmpty) ...[
                      SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Case link if present
                    if (event.caseName != null) ...[
                      SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 14,
                            color: event.hasCaseWarning
                                ? Colors.orange
                                : Colors.grey.shade600,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.caseName!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: event.hasCaseWarning
                                        ? Colors.orange
                                        : Colors.grey.shade600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (event.hasCaseWarning)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.warning_amber,
                                size: 14,
                                color: Colors.orange,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Recurring indicator
              if (event.recurrence != null || event.isRecurringInstance)
                Icon(
                  Icons.repeat,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(EventStatus status) {
    Color color;
    switch (status) {
      case EventStatus.completed:
        color = Colors.green;
        break;
      case EventStatus.cancelled:
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
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
