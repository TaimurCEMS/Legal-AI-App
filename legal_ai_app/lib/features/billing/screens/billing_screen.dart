import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/case_model.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/spacing.dart';
import '../../cases/providers/case_provider.dart';
import '../../common/widgets/cards/app_card.dart';
import '../../common/widgets/error_message.dart';
import '../../common/widgets/text_fields/app_text_field.dart';
import '../../home/providers/org_provider.dart';
import '../providers/invoice_provider.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  static const String _allCasesFilterValue = '__ALL_CASES__';

  String _caseFilter = _allCasesFilterValue;
  InvoiceStatus? _statusFilter;

  bool _isLoading = false;
  String? _loadedOrgId;

  Future<void> _ensureLoaded({bool force = false}) async {
    if (!mounted) return;
    final orgProvider = context.read<OrgProvider>();
    final caseProvider = context.read<CaseProvider>();
    final invoiceProvider = context.read<InvoiceProvider>();

    final org = orgProvider.selectedOrg;
    if (org == null) return;

    if (!force && _isLoading) return;
    if (!force && _loadedOrgId == org.orgId) return;

    setState(() => _isLoading = true);
    try {
      if (caseProvider.cases.isEmpty && !caseProvider.isLoading) {
        await caseProvider.loadCases(org: org);
      }
      await invoiceProvider.loadInvoices(
        org: org,
        caseId: _caseFilter == _allCasesFilterValue ? null : _caseFilter,
        status: _statusFilter,
      );
      _loadedOrgId = org.orgId;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLoaded();
    });
  }

  String _caseLabel(List<CaseModel> cases, String caseId) {
    final match = cases.where((c) => c.caseId == caseId).toList();
    if (match.isNotEmpty) return match.first.title;
    return caseId;
  }

  String _money(String currency, int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final major = abs ~/ 100;
    final minor = abs % 100;
    return '$sign$currency $major.${minor.toString().padLeft(2, '0')}';
  }

  Color _statusColor(BuildContext context, InvoiceStatus s) {
    final scheme = Theme.of(context).colorScheme;
    switch (s) {
      case InvoiceStatus.draft:
        return scheme.secondary;
      case InvoiceStatus.sent:
        return scheme.primary;
      case InvoiceStatus.paid:
        return Colors.green.shade700;
      case InvoiceStatus.voided:
        return scheme.error;
    }
  }

  Future<void> _showCreateInvoiceSheet({
    required OrgModel org,
  }) async {
    final cases = context.read<CaseProvider>().cases;
    final invoiceProvider = context.read<InvoiceProvider>();

    String? selectedCaseId = cases.isNotEmpty ? cases.first.caseId : null;
    final now = DateTime.now();
    DateTime from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    DateTime to = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final rateCtrl = TextEditingController(text: '250.00'); // $250/hr default
    final noteCtrl = TextEditingController();
    String currency = 'USD';

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
                            'Create Invoice',
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
                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedCaseId),
                      initialValue: selectedCaseId,
                      decoration: const InputDecoration(labelText: 'Case'),
                      items: cases
                          .map((c) => DropdownMenuItem(value: c.caseId, child: Text(c.title)))
                          .toList(),
                      onChanged: (v) => setSheetState(() => selectedCaseId = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Range: ${from.toLocal().toString().substring(0, 10)} → ${to.toLocal().toString().substring(0, 10)}',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: ctx,
                              firstDate: DateTime(now.year - 2),
                              lastDate: DateTime(now.year + 2),
                              initialDateRange: DateTimeRange(start: from, end: to),
                            );
                            if (picked == null) return;
                            setSheetState(() {
                              from = DateTime(picked.start.year, picked.start.month, picked.start.day);
                              to = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
                            });
                          },
                          icon: const Icon(Icons.date_range),
                          label: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Hourly rate',
                            controller: rateCtrl,
                            keyboardType: TextInputType.number,
                            hint: 'e.g. 250.00',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        DropdownButton<String>(
                          value: currency,
                          items: const [
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                          ],
                          onChanged: (v) => setSheetState(() => currency = v ?? 'USD'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Note (optional)',
                      controller: noteCtrl,
                      maxLines: 3,
                      hint: 'Shown on the invoice PDF',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: invoiceProvider.isUpdating
                          ? null
                          : () async {
                              if (selectedCaseId == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Please select a case.')),
                                );
                                return;
                              }
                              final rawRate = rateCtrl.text.trim().replaceAll('\$', '');
                              final parsed = double.tryParse(rawRate);
                              if (parsed == null || parsed <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Enter a valid hourly rate.')),
                                );
                                return;
                              }
                              final rateCents = (parsed * 100).round();
                              final created = await invoiceProvider.createInvoice(
                                org: org,
                                caseId: selectedCaseId!,
                                from: from,
                                to: to,
                                rateCents: rateCents,
                                currency: currency,
                                note: noteCtrl.text,
                              );
                              if (!mounted) return;
                              if (created != null) {
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Invoice created (${created.invoiceNumber ?? created.invoiceId}).')),
                                );
                              } else if (ctx.mounted && invoiceProvider.errorMessage != null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(invoiceProvider.errorMessage!)),
                                );
                              }
                            },
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    rateCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _showInvoiceDetailsSheet({
    required OrgModel org,
    required String invoiceId,
  }) async {
    final invoiceProvider = context.read<InvoiceProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return FutureBuilder<InvoiceModel?>(
              future: invoiceProvider.getInvoiceDetails(org: org, invoiceId: invoiceId),
              builder: (ctx, snap) {
                final inv = snap.data;
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (inv == null) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: ErrorMessage(
                      title: 'Invoice',
                      message: invoiceProvider.errorMessage ?? 'Failed to load invoice.',
                      onRetry: () {
                        Navigator.of(ctx).pop();
                        _showInvoiceDetailsSheet(org: org, invoiceId: invoiceId);
                      },
                    ),
                  );
                }

                final canExport = inv.status != InvoiceStatus.voided;

                return Material(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              inv.invoiceNumber ?? inv.invoiceId,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Chip(
                            label: Text(inv.status.value.toUpperCase()),
                            backgroundColor: _statusColor(context, inv.status).withValues(alpha: 0.15),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(_money(inv.currency, inv.totalCents)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          FilledButton.icon(
                            onPressed: !canExport || invoiceProvider.isUpdating
                                ? null
                                : () async {
                                    final documentId = await invoiceProvider.exportInvoicePdf(
                                      org: org,
                                      invoiceId: inv.invoiceId,
                                    );
                                    if (!mounted) return;
                                    if (documentId != null && ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                      context.push('${RouteNames.documentDetails}/$documentId');
                                    } else if (ctx.mounted && invoiceProvider.errorMessage != null) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text(invoiceProvider.errorMessage!)),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export PDF'),
                          ),
                          FilledButton.icon(
                            onPressed: invoiceProvider.isUpdating
                                ? null
                                : () async {
                                    final ok = await _showRecordPaymentDialog(ctx, org, inv.invoiceId, inv.currency);
                                    if (ok && ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                      _showInvoiceDetailsSheet(org: org, invoiceId: inv.invoiceId);
                                    }
                                  },
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Record payment'),
                          ),
                          OutlinedButton(
                            onPressed: inv.status == InvoiceStatus.draft && !invoiceProvider.isUpdating
                                ? () async {
                                    final updated = await invoiceProvider.updateInvoice(
                                      org: org,
                                      invoiceId: inv.invoiceId,
                                      status: InvoiceStatus.sent,
                                    );
                                    if (updated != null && ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                      _showInvoiceDetailsSheet(org: org, invoiceId: inv.invoiceId);
                                    }
                                  }
                                : null,
                            child: const Text('Mark sent'),
                          ),
                          OutlinedButton(
                            onPressed: inv.status != InvoiceStatus.voided && inv.status != InvoiceStatus.paid && !invoiceProvider.isUpdating
                                ? () async {
                                    final confirm = await showDialog<bool>(
                                      context: ctx,
                                      builder: (dctx) => AlertDialog(
                                        title: const Text('Void invoice?'),
                                        content: const Text('This invoice will be marked as void.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                                          ElevatedButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Void')),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    final updated = await invoiceProvider.updateInvoice(
                                      org: org,
                                      invoiceId: inv.invoiceId,
                                      status: InvoiceStatus.voided,
                                    );
                                    if (updated != null && ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                      _showInvoiceDetailsSheet(org: org, invoiceId: inv.invoiceId);
                                    }
                                  }
                                : null,
                            child: const Text('Void'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Totals', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Subtotal: ${_money(inv.currency, inv.subtotalCents)}'),
                            Text('Paid: ${_money(inv.currency, inv.paidCents)}'),
                            Text('Balance: ${_money(inv.currency, inv.balanceCents)}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Line items (${inv.lineItems.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: AppSpacing.sm),
                            if (inv.lineItems.isEmpty)
                              const Text('No line items found.'),
                            ...inv.lineItems.map(
                              (li) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(li.description),
                                subtitle: li.durationSeconds != null
                                    ? Text('${(li.durationSeconds! / 3600).toStringAsFixed(2)} hrs @ ${_money(inv.currency, li.rateCents)}')
                                    : null,
                                trailing: Text(_money(inv.currency, li.amountCents)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payments (${inv.payments.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: AppSpacing.sm),
                            if (inv.payments.isEmpty)
                              const Text('No payments recorded.'),
                            ...inv.payments.map(
                              (p) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(_money(inv.currency, p.amountCents)),
                                subtitle: Text(p.paidAt.toLocal().toString()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _showRecordPaymentDialog(
    BuildContext ctx,
    OrgModel org,
    String invoiceId,
    String currency,
  ) async {
    final invoiceProvider = context.read<InvoiceProvider>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Record payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Amount ($currency)',
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              hint: 'e.g. 500.00',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Note (optional)',
              controller: noteCtrl,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: invoiceProvider.isUpdating
                ? null
                : () async {
                    final raw = amountCtrl.text.trim().replaceAll('\$', '');
                    final parsed = double.tryParse(raw);
                    if (parsed == null || parsed <= 0) {
                      ScaffoldMessenger.of(dctx).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount.')),
                      );
                      return;
                    }
                    final cents = (parsed * 100).round();
                    final success = await invoiceProvider.recordPayment(
                      org: org,
                      invoiceId: invoiceId,
                      amountCents: cents,
                      note: noteCtrl.text,
                    );
                    if (success && dctx.mounted) {
                      Navigator.of(dctx).pop(true);
                    } else if (dctx.mounted && invoiceProvider.errorMessage != null) {
                      ScaffoldMessenger.of(dctx).showSnackBar(
                        SnackBar(content: Text(invoiceProvider.errorMessage!)),
                      );
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    amountCtrl.dispose();
    noteCtrl.dispose();
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrgProvider>();
    final caseProvider = context.watch<CaseProvider>();
    final invoiceProvider = context.watch<InvoiceProvider>();

    final org = orgProvider.selectedOrg;
    final role = orgProvider.currentMembership?.role ?? 'VIEWER';
    final isAdmin = role == 'ADMIN';

    if (org == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!isAdmin) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Billing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: AppSpacing.sm),
                Text('Billing is currently restricted to ADMIN users.'),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => _ensureLoaded(force: true),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_isLoading || invoiceProvider.isLoading) ...[
            const SizedBox(height: AppSpacing.md),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: AppSpacing.md),
          ],
          if (invoiceProvider.hasError && invoiceProvider.errorMessage != null) ...[
            ErrorMessage(
              title: 'Billing',
              message: invoiceProvider.errorMessage!,
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
                    const Expanded(
                      child: Text('Invoices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    TextButton.icon(
                      onPressed: invoiceProvider.isUpdating ? null : () => _showCreateInvoiceSheet(org: org),
                      icon: const Icon(Icons.add),
                      label: const Text('Create'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    DropdownButton<String>(
                      value: _caseFilter,
                      items: [
                        const DropdownMenuItem(value: _allCasesFilterValue, child: Text('All cases')),
                        ...caseProvider.cases.map((c) => DropdownMenuItem(value: c.caseId, child: Text(c.title))),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _caseFilter = v);
                        await invoiceProvider.loadInvoices(
                          org: org,
                          caseId: _caseFilter == _allCasesFilterValue ? null : _caseFilter,
                          status: _statusFilter,
                        );
                      },
                    ),
                    DropdownButton<InvoiceStatus?>(
                      value: _statusFilter,
                      hint: const Text('All statuses'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All statuses')),
                        DropdownMenuItem(value: InvoiceStatus.draft, child: Text('Draft')),
                        DropdownMenuItem(value: InvoiceStatus.sent, child: Text('Sent')),
                        DropdownMenuItem(value: InvoiceStatus.paid, child: Text('Paid')),
                        DropdownMenuItem(value: InvoiceStatus.voided, child: Text('Void')),
                      ],
                      onChanged: (v) async {
                        setState(() => _statusFilter = v);
                        await invoiceProvider.loadInvoices(
                          org: org,
                          caseId: _caseFilter == _allCasesFilterValue ? null : _caseFilter,
                          status: _statusFilter,
                        );
                      },
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        setState(() {
                          _caseFilter = _allCasesFilterValue;
                          _statusFilter = null;
                        });
                        await invoiceProvider.loadInvoices(org: org);
                      },
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (invoiceProvider.invoices.isEmpty && !_isLoading && !invoiceProvider.isLoading) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: Text('No invoices yet.')),
            ),
          ] else ...[
            ...invoiceProvider.invoices.map((inv) {
              final caseTitle = _caseLabel(caseProvider.cases, inv.caseId);
              final title = inv.invoiceNumber ?? inv.invoiceId;
              final subtitle = '$caseTitle • ${inv.issuedAt.toLocal().toString().substring(0, 10)}';
              return AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(title),
                  subtitle: Text(subtitle),
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(context, inv.status).withValues(alpha: 0.15),
                    child: Text(
                      inv.status.value.toUpperCase().substring(0, 1),
                      style: TextStyle(color: _statusColor(context, inv.status), fontWeight: FontWeight.w700),
                    ),
                  ),
                  trailing: Text(_money(inv.currency, inv.totalCents)),
                  onTap: () => _showInvoiceDetailsSheet(org: org, invoiceId: inv.invoiceId),
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

