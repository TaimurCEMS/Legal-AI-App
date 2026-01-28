import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/case_model.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/models/time_entry_model.dart';
import '../../../core/theme/spacing.dart';
import '../../../features/common/widgets/buttons/primary_button.dart';
import '../../../features/common/widgets/cards/app_card.dart';
import '../../../features/common/widgets/error_message.dart';
import '../../../features/common/widgets/text_fields/app_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cases/providers/case_provider.dart';
import '../../home/providers/member_provider.dart';
import '../../home/providers/org_provider.dart';
import '../providers/time_entry_provider.dart';

class TimeTrackingScreen extends StatefulWidget {
  const TimeTrackingScreen({super.key});

  @override
  State<TimeTrackingScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends State<TimeTrackingScreen> {
  Timer? _ticker;

  static const String _prefsDefaultBillableKey = 'time_tracking_default_billable';
  static const String _allCasesFilterValue = '__ALL_CASES__';

  bool _isLoading = false;
  String? _loadedOrgId;
  String? _loadedUserId;

  final TextEditingController _timerDescriptionCtrl = TextEditingController();
  String? _timerCaseId;
  bool _timerBillable = true;
  bool _defaultBillable = true;

  // List filters
  bool _entriesMineOnly = true;
  String? _entriesUserFilterUid; // admin-only; null => all users
  DateTime? _entriesFrom;
  DateTime? _entriesTo;
  String _entriesRangeLabel = 'Today';
  String _entriesCaseId = _allCasesFilterValue;
  bool? _entriesBillable; // null=all, true=billable, false=non-billable

  Future<void> _loadDefaultBillablePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_prefsDefaultBillableKey) ?? true;
      if (!mounted) return;
      setState(() {
        _defaultBillable = v;
        _timerBillable = v;
      });
    } catch (_) {
      // ignore preference errors; default remains true
    }
  }

  Future<void> _persistDefaultBillablePreference(bool v) async {
    // Persist a global default, but do NOT auto-sync the main timer toggle.
    // This prevents edits in dialogs/sheets from changing the main page switch.
    _defaultBillable = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsDefaultBillableKey, v);
    } catch (_) {
      // ignore preference errors
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _entriesFrom = DateTime(now.year, now.month, now.day);
    _entriesTo = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    _entriesRangeLabel = 'Today';
    // Default: billable ON (and remember last choice if available)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultBillablePreference();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _timerDescriptionCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLoaded();
    });
  }

  Future<void> _ensureLoaded({bool force = false}) async {
    if (!mounted) return;
    final orgProvider = context.read<OrgProvider>();
    final authProvider = context.read<AuthProvider>();
    final caseProvider = context.read<CaseProvider>();
    final timeProvider = context.read<TimeEntryProvider>();
    final memberProvider = context.read<MemberProvider>();

    final org = orgProvider.selectedOrg;
    final userId = authProvider.currentUser?.uid;
    if (org == null || userId == null) return;

    if (!force && _isLoading) return;
    if (!force && _loadedOrgId == org.orgId && _loadedUserId == userId) return;

    setState(() => _isLoading = true);
    try {
      // Ensure cases are available for dropdowns
      if (caseProvider.cases.isEmpty && !caseProvider.isLoading) {
        await caseProvider.loadCases(org: org);
      }

      // Best-effort: in team view, load members so "By user" shows displayName/email (ADMIN-only endpoint).
      final isAdmin = orgProvider.currentMembership?.role == 'ADMIN';
      if (!_entriesMineOnly && isAdmin && memberProvider.members.isEmpty && !memberProvider.isLoading) {
        await memberProvider.loadMembers(org: org);
      }

      await timeProvider.loadMyTimeToday(
        org: org,
        userId: _entriesMineOnly
            ? userId
            : ((orgProvider.currentMembership?.role == 'ADMIN' && _entriesUserFilterUid != null)
                ? _entriesUserFilterUid
                : null),
        from: _entriesFrom,
        to: _entriesTo,
        caseId: _entriesCaseId == _allCasesFilterValue ? null : _entriesCaseId,
        billable: _entriesBillable,
      );
      _loadedOrgId = org.orgId;
      _loadedUserId = userId;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setTodayRange() {
    final now = DateTime.now();
    setState(() {
      _entriesRangeLabel = 'Today';
      _entriesFrom = DateTime(now.year, now.month, now.day);
      _entriesTo = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    });
    _ensureLoaded(force: true);
  }

  void _setThisWeekRange() {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1)); // Monday
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
    setState(() {
      _entriesRangeLabel = 'This week';
      _entriesFrom = startOfWeek;
      _entriesTo = endOfWeek;
    });
    _ensureLoaded(force: true);
  }

  void _clearFilters() {
    setState(() {
      _entriesMineOnly = true;
      _entriesUserFilterUid = null;
      _entriesCaseId = _allCasesFilterValue;
      _entriesBillable = null;
    });
    _setTodayRange();
  }

  String _shortUid(String uid) {
    if (uid.length <= 8) return uid;
    return '${uid.substring(0, 6)}…${uid.substring(uid.length - 2)}';
  }

  String _userLabel(String uid, List<MemberModel> members) {
    final match = members.where((m) => m.uid == uid).toList();
    if (match.isNotEmpty) return match.first.displayLabel;
    return _shortUid(uid);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = DateTimeRange(
      start: _entriesFrom ?? DateTime(now.year, now.month, now.day),
      end: _entriesTo ?? DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked == null) return;
    setState(() {
      _entriesRangeLabel = 'Custom';
      _entriesFrom = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _entriesTo = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
    });
    _ensureLoaded(force: true);
  }

  String _caseLabel(List<CaseModel> cases, String? caseId) {
    if (caseId == null) return 'No case';
    final match = cases.where((c) => c.caseId == caseId).toList();
    if (match.isNotEmpty) return match.first.title;
    return caseId;
  }

  Future<void> _showManualEntrySheet({
    required OrgModel org,
    required String userId,
  }) async {
    final cases = context.read<CaseProvider>().cases;
    final timeProvider = context.read<TimeEntryProvider>();

    final descCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '30');
    String? selectedCaseId;
    var billable = _defaultBillable;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom: bottomInset + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add Manual Entry',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String?>(
                      key: ValueKey(selectedCaseId),
                      initialValue: selectedCaseId,
                      decoration: const InputDecoration(labelText: 'Case (optional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('No case')),
                        ...cases.map(
                          (c) => DropdownMenuItem(value: c.caseId, child: Text(c.title)),
                        ),
                      ],
                      onChanged: (v) => setSheetState(() => selectedCaseId = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Description',
                      controller: descCtrl,
                      maxLines: 3,
                      hint: 'What did you work on?',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Duration (minutes)',
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      hint: 'e.g. 30',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      value: billable,
                      title: const Text('Billable'),
                      onChanged: (v) {
                        setSheetState(() => billable = v);
                        _persistDefaultBillablePreference(v);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: 'Save',
                      onPressed: timeProvider.isUpdating
                          ? null
                          : () async {
                              final desc = descCtrl.text.trim();
                              final minutes = int.tryParse(durationCtrl.text.trim());
                              if (desc.isEmpty || minutes == null || minutes <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Enter a description and valid duration.')),
                                );
                                return;
                              }
                              final endAt = DateTime.now();
                              final startAt = endAt.subtract(Duration(minutes: minutes));
                              final ok = await timeProvider.addManualEntry(
                                org: org,
                                userId: userId,
                                startAt: startAt,
                                endAt: endAt,
                                description: desc,
                                billable: billable,
                                caseId: selectedCaseId,
                              );
                              if (ok && ctx.mounted) Navigator.of(ctx).pop();
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    descCtrl.dispose();
    durationCtrl.dispose();
  }

  Future<void> _showEditEntryDialog({
    required OrgModel org,
    required TimeEntryModel entry,
  }) async {
    final cases = context.read<CaseProvider>().cases;
    final timeProvider = context.read<TimeEntryProvider>();

    final descCtrl = TextEditingController(text: entry.description);
    var billable = entry.billable;
    String? selectedCaseId = entry.caseId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Time Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String?>(
                      key: ValueKey(selectedCaseId),
                      initialValue: selectedCaseId,
                      decoration: const InputDecoration(labelText: 'Case (optional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('No case')),
                        ...cases.map(
                          (c) => DropdownMenuItem(value: c.caseId, child: Text(c.title)),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => selectedCaseId = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      value: billable,
                      title: const Text('Billable'),
                      onChanged: (v) {
                        setDialogState(() => billable = v);
                        _persistDefaultBillablePreference(v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: timeProvider.isUpdating
                      ? null
                      : () async {
                          final ok = await timeProvider.updateEntry(
                            org: org,
                            timeEntryId: entry.timeEntryId,
                            description: descCtrl.text.trim(),
                            billable: billable,
                            caseId: selectedCaseId,
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop(ok);
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    descCtrl.dispose();
    if (saved == true) {
      // no-op (provider already updated)
    }
  }

  Future<void> _confirmDelete({
    required OrgModel org,
    required TimeEntryModel entry,
  }) async {
    final timeProvider = context.read<TimeEntryProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete time entry?'),
        content: const Text('This will remove the entry from your time log.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await timeProvider.deleteEntry(org: org, timeEntryId: entry.timeEntryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();
    final authProvider = context.watch<AuthProvider>();
    final caseProvider = context.watch<CaseProvider>();
    final memberProvider = context.watch<MemberProvider>();
    final timeProvider = context.watch<TimeEntryProvider>();
    final scheme = Theme.of(context).colorScheme;

    final org = orgProvider.selectedOrg;
    final userId = authProvider.currentUser?.uid;
    final isAdmin = orgProvider.currentMembership?.role == 'ADMIN';
    final role = orgProvider.currentMembership?.role ?? 'VIEWER';
    final canViewTeam = role != 'VIEWER';
    final members = memberProvider.members;

    if (org == null || userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final running = timeProvider.runningEntry;
    final now = DateTime.now();
    final runningElapsed = running != null ? running.elapsedSeconds(now) : 0;
    final from = _entriesFrom;
    final to = _entriesTo;
    final runningInRange = running != null &&
        (from == null || running.startAt.isAfter(from) || running.startAt.isAtSameMomentAs(from)) &&
        (to == null || running.startAt.isBefore(to) || running.startAt.isAtSameMomentAs(to));
    final totalWithRunning = timeProvider.todayTotalSeconds + (runningInRange ? runningElapsed : 0);

    return RefreshIndicator(
      onRefresh: () => _ensureLoaded(force: true),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_isLoading) ...[
            const SizedBox(height: AppSpacing.md),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: AppSpacing.md),
          ],
          if (timeProvider.hasError && timeProvider.errorMessage != null) ...[
            ErrorMessage(
              title: 'Time Tracking',
              message: timeProvider.errorMessage!,
              onRetry: () => _ensureLoaded(force: true),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        'Timer',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: timeProvider.isUpdating ? null : () => _showManualEntrySheet(org: org, userId: userId),
                      icon: const Icon(Icons.add),
                      label: const Text('Manual'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                if (running == null) ...[
                  DropdownButtonFormField<String?>(
                    key: ValueKey(_timerCaseId),
                    initialValue: _timerCaseId,
                    decoration: const InputDecoration(labelText: 'Case (optional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No case')),
                      ...caseProvider.cases.map(
                        (c) => DropdownMenuItem(value: c.caseId, child: Text(c.title)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _timerCaseId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Description (optional)',
                    controller: _timerDescriptionCtrl,
                    maxLines: 2,
                    hint: 'e.g., Draft motion, client call, research',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    value: _timerBillable,
                    title: const Text('Billable'),
                    onChanged: (v) {
                      setState(() => _timerBillable = v);
                      _persistDefaultBillablePreference(v);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Start Timer',
                    onPressed: timeProvider.isUpdating
                        ? null
                        : () async {
                            final ok = await timeProvider.startTimer(
                              org: org,
                              userId: userId,
                              caseId: _timerCaseId,
                              description: _timerDescriptionCtrl.text.trim().isEmpty
                                  ? null
                                  : _timerDescriptionCtrl.text.trim(),
                              billable: _timerBillable,
                            );
                            if (ok && mounted) {
                              _timerDescriptionCtrl.clear();
                            }
                          },
                  ),
                ] else ...[
                  Text(
                    'Running: ${TimeEntryModel.formatDuration(runningElapsed)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Case: ${_caseLabel(caseProvider.cases, running.caseId)}'),
                  if (running.description.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text('Note: ${running.description}'),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Stop Timer',
                    onPressed: timeProvider.isUpdating
                        ? null
                        : () async {
                            await timeProvider.stopTimer(org: org, userId: userId);
                          },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _entriesRangeLabel,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(TimeEntryModel.formatDuration(totalWithRunning)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('Mine'),
                      selected: _entriesMineOnly,
                      onSelected: _isLoading
                          ? null
                          : (v) async {
                              if (!v && !canViewTeam) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Your role can only view your own time entries.')),
                                );
                                return;
                              }
                              setState(() {
                                _entriesMineOnly = v;
                                if (v) _entriesUserFilterUid = null;
                              });

                              // Best effort: load members for admin user filter
                              if (!v && isAdmin && members.isEmpty && !memberProvider.isLoading) {
                                await context.read<MemberProvider>().loadMembers(org: org);
                              }

                              _ensureLoaded(force: true);
                            },
                    ),
                    if (isAdmin && !_entriesMineOnly)
                      DropdownButton<String?>(
                        value: _entriesUserFilterUid,
                        hint: const Text('All users'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All users')),
                          ...members.map((m) => DropdownMenuItem(value: m.uid, child: Text(m.displayLabel))),
                        ],
                        onChanged: _isLoading
                            ? null
                            : (v) {
                                setState(() => _entriesUserFilterUid = v);
                                _ensureLoaded(force: true);
                              },
                      ),
                    Builder(
                      builder: (_) {
                        final selected = _entriesRangeLabel == 'Today';
                        final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant.withValues(alpha: 0.75);
                        final bg = selected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.35);
                        return ChoiceChip(
                          label: const Text('Today'),
                          avatar: Icon(Icons.today, size: 18, color: fg),
                          selected: selected,
                          selectedColor: bg,
                          backgroundColor: bg,
                          labelStyle: TextStyle(color: fg),
                          shape: StadiumBorder(
                            side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
                          ),
                          onSelected: _isLoading ? null : (_) => _setTodayRange(),
                        );
                      },
                    ),
                    Builder(
                      builder: (_) {
                        final selected = _entriesRangeLabel == 'This week';
                        final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant.withValues(alpha: 0.75);
                        final bg = selected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.35);
                        return ChoiceChip(
                          label: const Text('This week'),
                          avatar: Icon(Icons.date_range, size: 18, color: fg),
                          selected: selected,
                          selectedColor: bg,
                          backgroundColor: bg,
                          labelStyle: TextStyle(color: fg),
                          shape: StadiumBorder(
                            side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
                          ),
                          onSelected: _isLoading ? null : (_) => _setThisWeekRange(),
                        );
                      },
                    ),
                    Builder(
                      builder: (_) {
                        final selected = _entriesRangeLabel == 'Custom';
                        final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant.withValues(alpha: 0.75);
                        final bg = selected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.35);
                        return ChoiceChip(
                          label: const Text('Custom'),
                          avatar: Icon(Icons.tune, size: 18, color: fg),
                          selected: selected,
                          selectedColor: bg,
                          backgroundColor: bg,
                          labelStyle: TextStyle(color: fg),
                          shape: StadiumBorder(
                            side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
                          ),
                          onSelected: _isLoading ? null : (_) => _pickCustomRange(),
                        );
                      },
                    ),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _clearFilters,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                    ),
                    DropdownButton<String>(
                      value: _entriesCaseId,
                      items: [
                        const DropdownMenuItem(value: _allCasesFilterValue, child: Text('All cases')),
                        ...caseProvider.cases.map((c) => DropdownMenuItem(value: c.caseId, child: Text(c.title))),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _entriesCaseId = v);
                        _ensureLoaded(force: true);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _entriesBillable == null,
                      onSelected: (_) {
                        setState(() => _entriesBillable = null);
                        _ensureLoaded(force: true);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Billable'),
                      selected: _entriesBillable == true,
                      onSelected: (_) {
                        setState(() => _entriesBillable = true);
                        _ensureLoaded(force: true);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Non-billable'),
                      selected: _entriesBillable == false,
                      onSelected: (_) {
                        setState(() => _entriesBillable = false);
                        _ensureLoaded(force: true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          if (timeProvider.todayEntries.isEmpty && !_isLoading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  _entriesMineOnly ? 'No entries in this range.' : 'No entries in this range.',
                ),
              ),
            ),
          ] else ...[
            ...timeProvider.todayEntries.map((e) {
              final title = e.description.trim().isEmpty ? 'Time Entry' : e.description.trim();
              final displaySeconds = e.status == TimeEntryStatus.running ? e.elapsedSeconds(now) : e.durationSeconds;
              final subtitle = [
                _caseLabel(caseProvider.cases, e.caseId),
                if (!_entriesMineOnly) 'By ${_userLabel(e.createdBy, members)}',
                e.billable ? 'Billable' : 'Non-billable',
                if (e.status == TimeEntryStatus.running) 'Running',
                '${e.startAt.hour.toString().padLeft(2, '0')}:${e.startAt.minute.toString().padLeft(2, '0')}',
              ].join(' • ');

              final canEdit = isAdmin || e.createdBy == userId;

              return AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(title),
                  subtitle: Text(subtitle),
                  leading: CircleAvatar(
                    child: Text(
                      TimeEntryModel.formatDuration(displaySeconds),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  trailing: canEdit
                      ? PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              _showEditEntryDialog(org: org, entry: e);
                            } else if (v == 'delete') {
                              _confirmDelete(org: org, entry: e);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        )
                      : null,
                ),
              );
            }),
          ],

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

