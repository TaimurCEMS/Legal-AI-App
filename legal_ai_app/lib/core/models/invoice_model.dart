DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value.toLocal();
  if (value is String) return DateTime.parse(value).toLocal();
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for InvoiceModel');
}

enum InvoiceStatus {
  draft('draft'),
  sent('sent'),
  paid('paid'),
  voided('void');

  final String value;
  const InvoiceStatus(this.value);

  static InvoiceStatus fromString(String value) {
    return InvoiceStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InvoiceStatus.draft,
    );
  }
}

class InvoiceLineItemModel {
  final String lineItemId;
  final String description;
  final String? timeEntryId;
  final DateTime? startAt;
  final DateTime? endAt;
  final int? durationSeconds;
  final int rateCents;
  final int amountCents;

  const InvoiceLineItemModel({
    required this.lineItemId,
    required this.description,
    required this.timeEntryId,
    required this.startAt,
    required this.endAt,
    required this.durationSeconds,
    required this.rateCents,
    required this.amountCents,
  });

  factory InvoiceLineItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItemModel(
      lineItemId: json['lineItemId'] as String? ?? json['id'] as String,
      description: json['description'] as String? ?? '',
      timeEntryId: json['timeEntryId'] as String?,
      startAt: json['startAt'] != null ? _parseTimestamp(json['startAt']) : null,
      endAt: json['endAt'] != null ? _parseTimestamp(json['endAt']) : null,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      rateCents: (json['rateCents'] as num?)?.toInt() ?? 0,
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class InvoicePaymentModel {
  final String paymentId;
  final int amountCents;
  final DateTime paidAt;
  final String? note;
  final DateTime createdAt;
  final String createdBy;

  const InvoicePaymentModel({
    required this.paymentId,
    required this.amountCents,
    required this.paidAt,
    required this.note,
    required this.createdAt,
    required this.createdBy,
  });

  factory InvoicePaymentModel.fromJson(Map<String, dynamic> json) {
    return InvoicePaymentModel(
      paymentId: json['paymentId'] as String? ?? json['id'] as String,
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      paidAt: _parseTimestamp(json['paidAt']),
      note: json['note'] as String?,
      createdAt: _parseTimestamp(json['createdAt']),
      createdBy: json['createdBy'] as String? ?? '',
    );
  }
}

class InvoiceModel {
  final String invoiceId;
  final String orgId;
  final String caseId;
  final InvoiceStatus status;
  final String? invoiceNumber;
  final String currency;
  final int subtotalCents;
  final int paidCents;
  final int totalCents;
  final DateTime issuedAt;
  final DateTime? dueAt;
  final String? note;
  final int lineItemCount;

  final List<InvoiceLineItemModel> lineItems;
  final List<InvoicePaymentModel> payments;

  const InvoiceModel({
    required this.invoiceId,
    required this.orgId,
    required this.caseId,
    required this.status,
    required this.invoiceNumber,
    required this.currency,
    required this.subtotalCents,
    required this.paidCents,
    required this.totalCents,
    required this.issuedAt,
    required this.dueAt,
    required this.note,
    required this.lineItemCount,
    this.lineItems = const [],
    this.payments = const [],
  });

  int get balanceCents => (totalCents - paidCents) < 0 ? 0 : (totalCents - paidCents);

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final lineItemsJson = (json['lineItems'] as List<dynamic>?) ?? const [];
    final paymentsJson = (json['payments'] as List<dynamic>?) ?? const [];

    return InvoiceModel(
      invoiceId: json['invoiceId'] as String? ?? json['id'] as String,
      orgId: json['orgId'] as String,
      caseId: json['caseId'] as String,
      status: InvoiceStatus.fromString(json['status'] as String? ?? 'draft'),
      invoiceNumber: json['invoiceNumber'] as String?,
      currency: json['currency'] as String? ?? 'USD',
      subtotalCents: (json['subtotalCents'] as num?)?.toInt() ?? 0,
      paidCents: (json['paidCents'] as num?)?.toInt() ?? 0,
      totalCents: (json['totalCents'] as num?)?.toInt() ?? 0,
      issuedAt: _parseTimestamp(json['issuedAt']),
      dueAt: json['dueAt'] != null ? _parseTimestamp(json['dueAt']) : null,
      note: json['note'] as String?,
      lineItemCount: (json['lineItemCount'] as num?)?.toInt() ?? 0,
      lineItems: lineItemsJson
          .map((e) => InvoiceLineItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      payments: paymentsJson
          .map((e) => InvoicePaymentModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

