import 'package:flutter_test/flutter_test.dart';
import 'package:legal_ai_app/core/models/org_stats_model.dart';

void main() {
  group('OrgStatsModel', () {
    test('fromJson handles full payload', () {
      final json = {
        'orgId': 'org-1',
        'orgName': 'Acme Law',
        'plan': 'PRO',
        'counts': {
          'members': 5,
          'cases': 10,
          'clients': 8,
          'documents': 50,
          'tasks': 20,
          'events': 15,
          'notes': 30,
          'timeEntries': 100,
          'invoices': 5,
        },
        'recentActivity': {
          'last30Days': {
            'casesCreated': 2,
            'documentsUploaded': 10,
            'tasksCreated': 5,
            'eventsCreated': 3,
          },
        },
        'storage': {'totalMB': 256.5, 'totalBytes': 268435456},
      };

      final model = OrgStatsModel.fromJson(json);

      expect(model.orgId, 'org-1');
      expect(model.orgName, 'Acme Law');
      expect(model.plan, 'PRO');
      expect(model.counts.members, 5);
      expect(model.counts.cases, 10);
      expect(model.counts.documents, 50);
      expect(model.recentActivity.last30Days?.casesCreated, 2);
      expect(model.recentActivity.last30Days?.documentsUploaded, 10);
      expect(model.storage.totalMB, 256.5);
      expect(model.storage.totalBytes, 268435456);
    });

    test('fromJson handles empty counts and storage', () {
      final json = {
        'orgId': 'org-2',
        'orgName': 'New Org',
        'counts': {},
        'recentActivity': {},
        'storage': {},
      };

      final model = OrgStatsModel.fromJson(json);

      expect(model.plan, 'FREE');
      expect(model.counts.members, 0);
      expect(model.counts.cases, 0);
      expect(model.storage.totalMB, 0);
      expect(model.storage.totalBytes, 0);
      expect(model.recentActivity.last30Days, isNull);
    });
  });

  group('OrgStatsCounts', () {
    test('fromJson defaults missing fields to 0', () {
      final model = OrgStatsCounts.fromJson({'members': 1});
      expect(model.members, 1);
      expect(model.cases, 0);
      expect(model.invoices, 0);
    });
  });

  group('StorageInfo', () {
    test('fromJson accepts num for totalMB', () {
      final model = StorageInfo.fromJson({'totalMB': 100, 'totalBytes': 1024});
      expect(model.totalMB, 100.0);
      expect(model.totalBytes, 1024);
    });
  });
}
