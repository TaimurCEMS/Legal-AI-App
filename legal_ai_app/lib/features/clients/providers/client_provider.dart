import 'package:flutter/foundation.dart';

import '../../../core/models/client_model.dart';
import '../../../core/models/org_model.dart';
import '../../../core/services/client_service.dart';

class ClientProvider with ChangeNotifier {
  final ClientService _clientService = ClientService();

  final List<ClientModel> _clients = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ClientModel> get clients => List.unmodifiable(_clients);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  Future<void> loadClients({
    required OrgModel org,
    String? search,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _clients.clear(); // Clear existing clients to show loading state immediately
    notifyListeners();

    try {
      final result = await _clientService.listClients(
        org: org,
        search: search,
      );
      _clients.addAll(result.clients);
      _errorMessage = null; // Clear error on success
    } catch (e) {
      _errorMessage = e.toString();
      // Don't clear clients if we had some before (preserve state on error)
      // But if this is a fresh load, clients will be empty which is correct
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createClient({
    required OrgModel org,
    required String name,
    String? email,
    String? phone,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _clientService.createClient(
        org: org,
        name: name,
        email: email,
        phone: phone,
        notes: notes,
      );
      // Reload clients list
      await loadClients(org: org);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateClient({
    required OrgModel org,
    required String clientId,
    String? name,
    String? email,
    String? phone,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _clientService.updateClient(
        org: org,
        clientId: clientId,
        name: name,
        email: email,
        phone: phone,
        notes: notes,
      );
      // Reload clients list
      await loadClients(org: org);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteClient({
    required OrgModel org,
    required String clientId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _clientService.deleteClient(
        org: org,
        clientId: clientId,
      );
      // Remove from local list
      _clients.removeWhere((c) => c.clientId == clientId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all clients (used when switching organizations)
  void clearClients() {
    _clients.clear();
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
