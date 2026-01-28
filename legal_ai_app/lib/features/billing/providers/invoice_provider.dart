import 'package:flutter/foundation.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/invoice_service.dart';

class InvoiceProvider with ChangeNotifier {
  final InvoiceService _service = InvoiceService();

  final List<InvoiceModel> _invoices = [];
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;

  List<InvoiceModel> get invoices => List.unmodifiable(_invoices);
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  void clear() {
    _invoices.clear();
    _isLoading = false;
    _isUpdating = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadInvoices({
    required OrgModel org,
    String? caseId,
    InvoiceStatus? status,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _service.listInvoices(
        org: org,
        caseId: caseId,
        status: status,
        limit: 200,
        offset: 0,
      );
      _invoices
        ..clear()
        ..addAll(res.invoices);
    } catch (e) {
      final errorStr = e.toString();
      _errorMessage = errorStr.replaceFirst(RegExp(r'^Exception:\s*'), '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InvoiceModel?> createInvoice({
    required OrgModel org,
    required String caseId,
    required DateTime from,
    required DateTime to,
    required int rateCents,
    String currency = 'USD',
    DateTime? dueAt,
    String? note,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _service.createInvoice(
        org: org,
        caseId: caseId,
        from: from,
        to: to,
        rateCents: rateCents,
        currency: currency,
        dueAt: dueAt,
        note: note,
      );
      _invoices.insert(0, created);
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<InvoiceModel?> getInvoiceDetails({
    required OrgModel org,
    required String invoiceId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final inv = await _service.getInvoice(org: org, invoiceId: invoiceId);
      return inv;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InvoiceModel?> updateInvoice({
    required OrgModel org,
    required String invoiceId,
    InvoiceStatus? status,
    DateTime? dueAt,
    String? note,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _service.updateInvoice(
        org: org,
        invoiceId: invoiceId,
        status: status,
        dueAt: dueAt,
        note: note,
      );
      final idx = _invoices.indexWhere((i) => i.invoiceId == invoiceId);
      if (idx != -1) _invoices[idx] = updated;
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> recordPayment({
    required OrgModel org,
    required String invoiceId,
    required int amountCents,
    DateTime? paidAt,
    String? note,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.recordPayment(
        org: org,
        invoiceId: invoiceId,
        amountCents: amountCents,
        paidAt: paidAt,
        note: note,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<String?> exportInvoicePdf({
    required OrgModel org,
    required String invoiceId,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _service.exportInvoicePdf(org: org, invoiceId: invoiceId);
      return res.documentId;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }
}

