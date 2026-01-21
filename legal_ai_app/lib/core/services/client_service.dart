import 'package:flutter/foundation.dart';

import '../models/client_model.dart';
import '../models/org_model.dart';
import 'cloud_functions_service.dart';

/// Service wrapper around CloudFunctionsService for client operations.
class ClientService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();

  Future<ClientModel> createClient({
    required OrgModel org,
    required String name,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final response = await _functionsService.callFunction('clientCreate', {
      'orgId': org.orgId,
      'name': name,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });

    if (response['success'] == true && response['data'] != null) {
      return ClientModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('ClientService.createClient error: $response');
    final message = response['error']?['message'] ??
        'Failed to create client. Please try again.';
    throw message;
  }

  Future<ClientModel> getClient({
    required OrgModel org,
    required String clientId,
  }) async {
    final response = await _functionsService.callFunction('clientGet', {
      'orgId': org.orgId,
      'clientId': clientId,
    });

    if (response['success'] == true && response['data'] != null) {
      return ClientModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('ClientService.getClient error: $response');
    final message = response['error']?['message'] ??
        'Failed to load client. Please try again.';
    throw message;
  }

  Future<({List<ClientModel> clients, int total, bool hasMore})> listClients({
    required OrgModel org,
    int limit = 50,
    int offset = 0,
    String? search,
  }) async {
    final response = await _functionsService.callFunction('clientList', {
      'orgId': org.orgId,
      'limit': limit,
      'offset': offset,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });

    if (response['success'] == true && response['data'] != null) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final list = (data['clients'] as List<dynamic>? ?? [])
          .map((e) => ClientModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total = data['total'] as int? ?? list.length;
      final hasMore = data['hasMore'] as bool? ?? false;
      return (clients: list, total: total, hasMore: hasMore);
    }

    debugPrint('ClientService.listClients error: $response');
    final message = response['error']?['message'] ??
        'Failed to load clients. Please try again.';
    throw message;
  }

  Future<ClientModel> updateClient({
    required OrgModel org,
    required String clientId,
    String? name,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'orgId': org.orgId,
      'clientId': clientId,
    };

    if (name != null) payload['name'] = name;
    if (email != null) payload['email'] = email;
    if (phone != null) payload['phone'] = phone;
    if (notes != null) payload['notes'] = notes;

    final response =
        await _functionsService.callFunction('clientUpdate', payload);

    if (response['success'] == true && response['data'] != null) {
      return ClientModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }

    debugPrint('ClientService.updateClient error: $response');
    final message = response['error']?['message'] ??
        'Failed to update client. Please try again.';
    throw message;
  }

  Future<void> deleteClient({
    required OrgModel org,
    required String clientId,
  }) async {
    final response = await _functionsService.callFunction('clientDelete', {
      'orgId': org.orgId,
      'clientId': clientId,
    });

    if (response['success'] == true) {
      return;
    }

    debugPrint('ClientService.deleteClient error: $response');
    final message = response['error']?['message'] ??
        'Failed to delete client. Please try again.';
    throw message;
  }
}
