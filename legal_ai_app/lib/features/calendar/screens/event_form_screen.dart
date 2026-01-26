import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/case_model.dart';
import '../../../core/theme/spacing.dart';
import '../../home/providers/org_provider.dart';
import '../../cases/providers/case_provider.dart';
import '../providers/event_provider.dart';
import '../../common/widgets/buttons/primary_button.dart';
import '../../common/widgets/text_fields/app_text_field.dart';

/// Event Form Screen - Create or Edit events (Slice 7)
class EventFormScreen extends StatefulWidget {
  final String? eventId; // null for create, non-null for edit
  final DateTime? prefilledDate; // Pre-filled date for new events (from calendar click)

  const EventFormScreen({super.key, this.eventId, this.prefilledDate});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  EventType _eventType = EventType.meeting;
  EventPriority _priority = EventPriority.medium;
  EventVisibility _visibility = EventVisibility.org;
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _allDay = false;
  List<ReminderModel> _reminders = [const ReminderModel(minutesBefore: 30)];
  String? _selectedCaseId; // Optional case linkage
  
  bool _isLoading = false;
  bool _isEditMode = false;
  EventModel? _existingEvent;

  /// Returns available visibility options based on whether a case is selected
  List<EventVisibility> get _availableVisibilityOptions {
    if (_selectedCaseId != null) {
      // All options available when case is selected
      return EventVisibility.values;
    } else {
      // Only ORG and PRIVATE when no case
      return [EventVisibility.org, EventVisibility.private_];
    }
  }

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.eventId != null;
    if (_isEditMode) {
      _loadExistingEvent();
    } else if (widget.prefilledDate != null) {
      // Pre-fill date from calendar click
      _startDate = widget.prefilledDate!;
      // Set default time to 9:00 AM
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      // Set end time to 10:00 AM (1 hour later)
      _endDate = widget.prefilledDate!;
      _endTime = const TimeOfDay(hour: 10, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingEvent() async {
    setState(() => _isLoading = true);
    
    final orgProvider = context.read<OrgProvider>();
    final eventProvider = context.read<EventProvider>();
    
    if (orgProvider.selectedOrg == null) return;

    await eventProvider.loadEventDetails(
      org: orgProvider.selectedOrg!,
      eventId: widget.eventId!,
    );

    final event = eventProvider.selectedEvent;
    if (event != null) {
      setState(() {
        _existingEvent = event;
        _titleController.text = event.title;
        _descriptionController.text = event.description ?? '';
        _locationController.text = event.location ?? '';
        _notesController.text = event.notes ?? '';
        _eventType = event.eventType;
        _priority = event.priority;
        _selectedCaseId = event.caseId; // Load linked case
        _visibility = event.visibility;
        _startDate = event.startDateTime;
        _startTime = TimeOfDay.fromDateTime(event.startDateTime);
        if (event.endDateTime != null) {
          _endDate = event.endDateTime;
          _endTime = TimeOfDay.fromDateTime(event.endDateTime!);
        }
        _allDay = event.allDay;
        _reminders = event.reminders.isNotEmpty
            ? event.reminders
            : [const ReminderModel(minutesBefore: 30)];
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // If end date is before start date, adjust it
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : (_endTime ?? _startTime),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final orgProvider = context.read<OrgProvider>();
    final eventProvider = context.read<EventProvider>();

    if (orgProvider.selectedOrg == null) {
      setState(() => _isLoading = false);
      return;
    }

    final startDateTime = _allDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day)
        : _combineDateAndTime(_startDate, _startTime);

    DateTime? endDateTime;
    if (_endDate != null || _endTime != null) {
      final endDateValue = _endDate ?? _startDate;
      final endTimeValue = _endTime ?? _startTime.replacing(hour: _startTime.hour + 1);
      endDateTime = _allDay
          ? DateTime(endDateValue.year, endDateValue.month, endDateValue.day, 23, 59)
          : _combineDateAndTime(endDateValue, endTimeValue);
    }

    bool success;
    if (_isEditMode && _existingEvent != null) {
      success = await eventProvider.updateEvent(
        org: orgProvider.selectedOrg!,
        eventId: _existingEvent!.eventId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        eventType: _eventType,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        allDay: _allDay,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        reminders: _reminders,
        priority: _priority,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        visibility: _visibility,
        clearDescription: _descriptionController.text.trim().isEmpty &&
            (_existingEvent?.description?.isNotEmpty ?? false),
        clearLocation: _locationController.text.trim().isEmpty &&
            (_existingEvent?.location?.isNotEmpty ?? false),
        clearNotes: _notesController.text.trim().isEmpty &&
            (_existingEvent?.notes?.isNotEmpty ?? false),
      );
    } else {
      success = await eventProvider.createEvent(
        org: orgProvider.selectedOrg!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        eventType: _eventType,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        allDay: _allDay,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        reminders: _reminders,
        priority: _priority,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        visibility: _visibility,
        caseId: _selectedCaseId,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      context.pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Event updated' : 'Event created'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eventProvider.errorMessage ?? 'Failed to save event'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Event' : 'New Event'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && _isEditMode && _existingEvent == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    AppTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'Enter event title',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Title is required';
                        }
                        if (value.trim().length > 200) {
                          return 'Title must be 200 characters or less';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Event Type
                    _buildDropdownField<EventType>(
                      label: 'Event Type',
                      value: _eventType,
                      items: EventType.values,
                      getLabel: (e) => e.displayName,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _eventType = value);
                        }
                      },
                    ),
                    SizedBox(height: AppSpacing.md),

                    // All Day toggle
                    SwitchListTile(
                      title: const Text('All Day'),
                      value: _allDay,
                      onChanged: (value) {
                        setState(() => _allDay = value);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Start Date/Time
                    _buildDateTimeRow(
                      label: 'Start',
                      date: _startDate,
                      time: _startTime,
                      showTime: !_allDay,
                      onDateTap: () => _selectDate(true),
                      onTimeTap: () => _selectTime(true),
                    ),
                    SizedBox(height: AppSpacing.md),

                    // End Date/Time (optional)
                    _buildDateTimeRow(
                      label: 'End',
                      date: _endDate,
                      time: _endTime,
                      showTime: !_allDay,
                      onDateTap: () => _selectDate(false),
                      onTimeTap: () => _selectTime(false),
                      optional: true,
                      onClear: () {
                        setState(() {
                          _endDate = null;
                          _endTime = null;
                        });
                      },
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Location
                    AppTextField(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'Enter location (optional)',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Priority
                    _buildDropdownField<EventPriority>(
                      label: 'Priority',
                      value: _priority,
                      items: EventPriority.values,
                      getLabel: (e) => e.displayName,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _priority = value);
                        }
                      },
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Link to Case (optional)
                    _buildCaseSelector(),
                    SizedBox(height: AppSpacing.md),

                    // Visibility (options depend on case selection)
                    _buildVisibilitySelector(),
                    SizedBox(height: AppSpacing.md),

                    // Reminders
                    _buildRemindersSection(),
                    SizedBox(height: AppSpacing.md),

                    // Description
                    AppTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Enter description (optional)',
                      maxLines: 3,
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Notes
                    AppTextField(
                      controller: _notesController,
                      label: 'Notes',
                      hint: 'Additional notes (optional)',
                      maxLines: 2,
                    ),
                    SizedBox(height: AppSpacing.lg),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        onPressed: _isLoading ? null : _saveEvent,
                        label: _isEditMode ? 'Update Event' : 'Create Event',
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) getLabel,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items
                  .map((item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(getLabel(item)),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  /// Build case selector dropdown (optional - for linking event to a case)
  Widget _buildCaseSelector() {
    final caseProvider = context.watch<CaseProvider>();
    final cases = caseProvider.cases;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Link to Case',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              ' (optional)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedCaseId,
              isExpanded: true,
              hint: const Text('No case linked'),
              items: [
                // Option for no case
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No case linked'),
                ),
                // All available cases
                ...cases.map((caseModel) => DropdownMenuItem<String?>(
                      value: caseModel.caseId,
                      child: Text(
                        caseModel.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCaseId = value;
                  // If changing from a case to no case, and visibility was CASE_ONLY,
                  // auto-switch to ORG
                  if (value == null && _visibility == EventVisibility.caseOnly) {
                    _visibility = EventVisibility.org;
                  }
                });
              },
            ),
          ),
        ),
        if (_selectedCaseId != null)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Event will be visible to case team members',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
      ],
    );
  }

  /// Build visibility selector with options based on case selection
  Widget _buildVisibilitySelector() {
    final availableOptions = _availableVisibilityOptions;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visibility',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<EventVisibility>(
              value: _visibility,
              isExpanded: true,
              items: availableOptions
                  .map((option) => DropdownMenuItem<EventVisibility>(
                        value: option,
                        child: Row(
                          children: [
                            Icon(
                              _getVisibilityIcon(option),
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 8),
                            Text(option.displayName),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _visibility = value);
                }
              },
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            _getVisibilityHelpText(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      ],
    );
  }

  IconData _getVisibilityIcon(EventVisibility visibility) {
    switch (visibility) {
      case EventVisibility.org:
        return Icons.business;
      case EventVisibility.caseOnly:
        return Icons.group;
      case EventVisibility.private_:
        return Icons.lock;
    }
  }

  String _getVisibilityHelpText() {
    switch (_visibility) {
      case EventVisibility.org:
        return 'Everyone in the organization can see this event';
      case EventVisibility.caseOnly:
        return 'Only members of the linked case can see this event';
      case EventVisibility.private_:
        return 'Only you can see this event';
    }
  }

  Widget _buildDateTimeRow({
    required String label,
    DateTime? date,
    TimeOfDay? time,
    required bool showTime,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
    bool optional = false,
    VoidCallback? onClear,
  }) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (optional)
              Text(
                ' (optional)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            // Date picker
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: onDateTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        date != null ? dateFormat.format(date) : 'Select date',
                        style: TextStyle(
                          color: date != null ? null : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showTime) ...[
              SizedBox(width: AppSpacing.sm),
              // Time picker
              Expanded(
                child: InkWell(
                  onTap: date != null || !optional ? onTimeTap : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            time != null
                                ? timeFormat.format(DateTime(2024, 1, 1, time.hour, time.minute))
                                : '--:--',
                            style: TextStyle(
                              color: time != null ? null : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (optional && (date != null || time != null)) ...[
              SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClear,
                tooltip: 'Clear',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildRemindersSection() {
    final reminderOptions = [
      const ReminderModel(minutesBefore: 0),
      const ReminderModel(minutesBefore: 5),
      const ReminderModel(minutesBefore: 10),
      const ReminderModel(minutesBefore: 15),
      const ReminderModel(minutesBefore: 30),
      const ReminderModel(minutesBefore: 60),
      const ReminderModel(minutesBefore: 120),
      const ReminderModel(minutesBefore: 1440),
      const ReminderModel(minutesBefore: 2880),
      const ReminderModel(minutesBefore: 10080),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reminders',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (_reminders.length < 3)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _reminders.add(const ReminderModel(minutesBefore: 30));
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        ...List.generate(_reminders.length, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _reminders[index].minutesBefore,
                        isExpanded: true,
                        items: reminderOptions
                            .map((r) => DropdownMenuItem<int>(
                                  value: r.minutesBefore,
                                  child: Text(r.displayName),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _reminders[index] = ReminderModel(minutesBefore: value);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.xs),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      _reminders.removeAt(index);
                    });
                  },
                  tooltip: 'Remove reminder',
                ),
              ],
            ),
          );
        }),
        if (_reminders.isEmpty)
          Text(
            'No reminders set',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
      ],
    );
  }
}
