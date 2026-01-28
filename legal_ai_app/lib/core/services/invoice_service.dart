import 'package:flutter/foundation.dart';
import '../models/invoice_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

class InvoiceService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  String _toUtcIso(DateTime dt) => dt.toUtc().toIso8601String();

  Future<({List<InvoiceModel> invoices, int total, bool hasMore})> listInvoices({
    required OrgModel org,
    int limit = 50,
    int offset = 0,
    String? caseId,
    InvoiceStatus? status,
  }) async {
    final response = await _functionsService.callFunction('invoiceList', {
      'orgId': org.orgId,
      'limit': limit,
      'offset': offset,
      if (caseId != null && caseId.trim().isNotEmpty) 'caseId': caseId.trim(),
      if (status != null) 'status': status.value,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['invoices'] as List<dynamic>? ?? [])
          .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total = data['total'] as int? ?? list.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (invoices: list, total: total, hasMore: hasMore);
    }

    debugPrint('InvoiceService.listInvoices error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to load invoices. Please try again.';
    throw message;
  }

  Future<InvoiceModel> createInvoice({
    required OrgModel org,
    required String caseId,
    required DateTime from,
    required DateTime to,
    required int rateCents,
    String currency = 'USD',
    DateTime? dueAt,
    String? note,
  }) async {
    final response = await _functionsService.callFunction('invoiceCreate', {
      'orgId': org.orgId,
      'caseId': caseId.trim(),
      'from': _toUtcIso(from),
      'to': _toUtcIso(to),
      'rateCents': rateCents,
      'currency': currency,
      if (dueAt != null) 'dueAt': _toUtcIso(dueAt),
      if (note != null) 'note': note,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      return InvoiceModel.fromJson(Map<String, dynamic>.from(data['invoice'] as Map));
    }

    debugPrint('InvoiceService.createInvoice error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to create invoice. Please try again.';
    throw message;
  }

  Future<InvoiceModel> getInvoice({
    required OrgModel org,
    required String invoiceId,
  }) async {
    final response = await _functionsService.callFunction('invoiceGet', {
      'orgId': org.orgId,
      'invoiceId': invoiceId,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      return InvoiceModel.fromJson(Map<String, dynamic>.from(data['invoice'] as Map));
    }

    debugPrint('InvoiceService.getInvoice error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to load invoice. Please try again.';
    throw message;
  }

  Future<InvoiceModel> updateInvoice({
    required OrgModel org,
    required String invoiceId,
    InvoiceStatus? status,
    DateTime? dueAt,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'invoiceId': invoiceId,
    };
    if (status != null) payload['status'] = status.value;
    if (dueAt != null) payload['dueAt'] = _toUtcIso(dueAt);
    if (note != null) payload['note'] = note;

    final response = await _functionsService.callFunction('invoiceUpdate', payload);

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      return InvoiceModel.fromJson(Map<String, dynamic>.from(data['invoice'] as Map));
    }

    debugPrint('InvoiceService.updateInvoice error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to update invoice. Please try again.';
    throw message;
  }

  Future<void> recordPayment({
    required OrgModel org,
    required String invoiceId,
    required int amountCents,
    DateTime? paidAt,
    String? note,
  }) async {
    final response = await _functionsService.callFunction('invoiceRecordPayment', {
      'orgId': org.orgId,
      'invoiceId': invoiceId,
      'amountCents': amountCents,
      if (paidAt != null) 'paidAt': _toUtcIso(paidAt),
      if (note != null) 'note': note,
    });

    if (response['success'] != true) {
      debugPrint('InvoiceService.recordPayment error: $response');
      final message = response['error']?['message'] ??
          'Failed to record payment. Please try again.';
      throw message;
    }
  }

  Future<({String documentId, String name})> exportInvoicePdf({
    required OrgModel org,
    required String invoiceId,
  }) async {
    final response = await _functionsService.callFunction('invoiceExport', {
      'orgId': org.orgId,
      'invoiceId': invoiceId,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final documentId = data['documentId'] as String? ?? '';
      final name = data['name'] as String? ?? 'Invoice.pdf';
      if (documentId.isEmpty) {
        throw 'Export succeeded but documentId was missing.';
      }
      return (documentId: documentId, name: name);
    }

    debugPrint('InvoiceService.exportInvoicePdf error: $response');
    final message =
        response['error']?['message'] ?? 'Failed to export invoice. Please try again.';
    throw message;
  }
}

