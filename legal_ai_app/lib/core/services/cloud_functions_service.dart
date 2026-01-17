import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';

/// Service for calling Firebase Cloud Functions
class CloudFunctionsService {
  // Use us-central1 region where functions are deployed
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Call a Cloud Function by name
  Future<Map<String, dynamic>> callFunction(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('CloudFunctionsService: Calling function: $functionName');
      debugPrint('CloudFunctionsService: Data: $data');
      
      // Use us-central1 region (where functions are deployed)
      final callable = _functions.httpsCallable(
        functionName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );
      
      final result = await callable.call(data);
      
      debugPrint('CloudFunctionsService: Response received');
      
      // Handle the response
      final responseData = result.data;
      
      if (responseData is Map) {
        return Map<String, dynamic>.from(responseData);
      } else if (responseData is String) {
        return jsonDecode(responseData) as Map<String, dynamic>;
      } else {
        return {'data': responseData};
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('CloudFunctionsService: FirebaseFunctionsException');
      debugPrint('  Code: ${e.code}');
      debugPrint('  Message: ${e.message}');
      debugPrint('  Details: ${e.details}');
      throw _handleFunctionsException(e);
    } catch (e) {
      debugPrint('CloudFunctionsService: Unexpected error: $e');
      throw 'An error occurred: ${e.toString()}';
    }
  }

  /// Call orgCreate (Firebase callable function)
  Future<Map<String, dynamic>> createOrg({
    required String name,
    String? description,
  }) async {
    return await callFunction('orgCreate', {
      'name': name,
      if (description != null) 'description': description,
    });
  }

  /// Call orgJoin (Firebase callable function)
  Future<Map<String, dynamic>> joinOrg({
    required String orgId,
  }) async {
    return await callFunction('orgJoin', {
      'orgId': orgId,
    });
  }

  /// Call memberGetMyMembership (Firebase callable function)
  Future<Map<String, dynamic>> getMyMembership({
    required String orgId,
  }) async {
    return await callFunction('memberGetMyMembership', {
      'orgId': orgId,
    });
  }

  /// Handle Cloud Functions exceptions
  String _handleFunctionsException(FirebaseFunctionsException e) {
    debugPrint('_handleFunctionsException: Code=${e.code}, Message=${e.message}, Details=${e.details}');
    
    switch (e.code) {
      case 'invalid-argument':
        return 'Invalid request. Please check your input.';
      case 'not-found':
        return 'Cloud Function not found. Make sure functions are deployed.';
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unauthenticated':
        return 'Please sign in to continue.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request timed out. Please try again.';
      case 'internal':
        return 'Internal server error: ${e.message ?? "Cloud Function error. Check if functions are deployed."}';
      case 'failed-precondition':
        return 'Precondition failed: ${e.message ?? "Please check your input."}';
      default:
        // Return more detailed error message
        final errorMsg = e.message ?? 'An error occurred. Please try again.';
        return 'Error (${e.code}): $errorMsg';
    }
  }
}
