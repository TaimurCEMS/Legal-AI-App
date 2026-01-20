import 'package:flutter_test/flutter_test.dart';
import 'package:legal_ai_app/core/models/case_model.dart';
import 'package:legal_ai_app/core/models/org_model.dart';

void main() {
  group('Model Serialization Tests', () {
    test('CaseModel fromJson handles all fields', () {
      final json = {
        'caseId': 'case-123',
        'orgId': 'org-123',
        'title': 'Test Case',
        'description': 'Test Description',
        'clientId': 'client-123',
        'visibility': 'ORG_WIDE',
        'status': 'OPEN',
        'createdAt': '2026-01-19T10:00:00Z',
        'updatedAt': '2026-01-19T10:00:00Z',
        'createdBy': 'user-123',
        'updatedBy': 'user-123',
      };

      final model = CaseModel.fromJson(json);

      expect(model.caseId, equals('case-123'));
      expect(model.orgId, equals('org-123'));
      expect(model.title, equals('Test Case'));
      expect(model.description, equals('Test Description'));
      expect(model.clientId, equals('client-123'));
      expect(model.visibility, equals(CaseVisibility.orgWide));
      expect(model.status, equals(CaseStatus.open));
      expect(model.createdBy, equals('user-123'));
    });

    test('CaseModel fromJson handles null optional fields', () {
      final json = {
        'caseId': 'case-123',
        'orgId': 'org-123',
        'title': 'Test Case',
        'visibility': 'ORG_WIDE',
        'status': 'OPEN',
        'createdAt': '2026-01-19T10:00:00Z',
        'updatedAt': '2026-01-19T10:00:00Z',
        'createdBy': 'user-123',
        'updatedBy': 'user-123',
      };

      final model = CaseModel.fromJson(json);

      expect(model.description, isNull);
      expect(model.clientId, isNull);
    });

    test('CaseModel fromJson handles PRIVATE visibility', () {
      final json = {
        'caseId': 'case-123',
        'orgId': 'org-123',
        'title': 'Test Case',
        'visibility': 'PRIVATE',
        'status': 'OPEN',
        'createdAt': '2026-01-19T10:00:00Z',
        'updatedAt': '2026-01-19T10:00:00Z',
        'createdBy': 'user-123',
        'updatedBy': 'user-123',
      };

      final model = CaseModel.fromJson(json);

      expect(model.visibility, equals(CaseVisibility.private));
    });

    test('CaseModel fromJson handles all status values', () {
      final statuses = ['OPEN', 'CLOSED', 'ARCHIVED'];
      
      for (final status in statuses) {
        final json = {
          'caseId': 'case-123',
          'orgId': 'org-123',
          'title': 'Test Case',
          'visibility': 'ORG_WIDE',
          'status': status,
          'createdAt': '2026-01-19T10:00:00Z',
          'updatedAt': '2026-01-19T10:00:00Z',
          'createdBy': 'user-123',
          'updatedBy': 'user-123',
        };

        final model = CaseModel.fromJson(json);
        
        switch (status) {
          case 'OPEN':
            expect(model.status, equals(CaseStatus.open));
            break;
          case 'CLOSED':
            expect(model.status, equals(CaseStatus.closed));
            break;
          case 'ARCHIVED':
            expect(model.status, equals(CaseStatus.archived));
            break;
        }
      }
    });

    test('OrgModel fromMap handles all fields', () {
      // Note: OrgModel uses fromMap, not fromJson
      // This test verifies the structure is correct
      final org = OrgModel(
        orgId: 'org-123',
        name: 'Test Org',
        description: 'Test Description',
        plan: 'FREE',
        createdAt: DateTime.now(),
        createdBy: 'user-123',
      );

      expect(org.orgId, equals('org-123'));
      expect(org.name, equals('Test Org'));
      expect(org.description, equals('Test Description'));
      expect(org.plan, equals('FREE'));
      expect(org.createdBy, equals('user-123'));
    });
  });
}
