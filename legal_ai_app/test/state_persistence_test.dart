import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  group('State Persistence Tests', () {
    test('SharedPreferences saves and loads org ID', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Save
      await prefs.setString('selected_org_id', 'test-org-123');
      await prefs.setString('selected_org', jsonEncode({
        'orgId': 'test-org-123',
        'name': 'Test Org',
        'plan': 'FREE',
      }));

      // Load
      final orgId = prefs.getString('selected_org_id');
      final orgJson = prefs.getString('selected_org');

      expect(orgId, equals('test-org-123'));
      expect(orgJson, isNotNull);

      final orgData = jsonDecode(orgJson!);
      expect(orgData['orgId'], equals('test-org-123'));
      expect(orgData['name'], equals('Test Org'));
    });

    test('SharedPreferences saves and loads user ID', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Save
      await prefs.setString('user_id', 'user-123');

      // Load
      final userId = prefs.getString('user_id');

      expect(userId, equals('user-123'));
    });

    test('SharedPreferences clears org data', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Save
      await prefs.setString('selected_org_id', 'test-org-123');
      await prefs.setString('selected_org', '{}');

      // Clear
      await prefs.remove('selected_org_id');
      await prefs.remove('selected_org');

      // Verify cleared
      expect(prefs.getString('selected_org_id'), isNull);
      expect(prefs.getString('selected_org'), isNull);
    });

    test('SharedPreferences persists across instances', () async {
      SharedPreferences.setMockInitialValues({});
      
      // First instance - save
      final prefs1 = await SharedPreferences.getInstance();
      await prefs1.setString('test_key', 'test_value');

      // Second instance - load
      final prefs2 = await SharedPreferences.getInstance();
      final value = prefs2.getString('test_key');

      expect(value, equals('test_value'));
    });
  });
}
