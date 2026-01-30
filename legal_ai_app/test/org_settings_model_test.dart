import 'package:flutter_test/flutter_test.dart';
import 'package:legal_ai_app/core/models/org_settings_model.dart';

void main() {
  group('OrgSettingsModel', () {
    test('fromJson handles all fields', () {
      final json = {
        'orgId': 'org-1',
        'name': 'Acme Law',
        'description': 'A firm',
        'plan': 'PRO',
        'timezone': 'America/New_York',
        'businessHours': {'start': '09:00', 'end': '18:00'},
        'defaultCaseVisibility': 'ORG',
        'defaultTaskVisibility': true,
        'website': 'https://acme.law',
        'address': {
          'street': '123 Main St',
          'city': 'Boston',
          'state': 'MA',
          'postalCode': '02101',
          'country': 'USA',
        },
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-29T00:00:00Z',
      };

      final model = OrgSettingsModel.fromJson(json);

      expect(model.orgId, 'org-1');
      expect(model.name, 'Acme Law');
      expect(model.description, 'A firm');
      expect(model.plan, 'PRO');
      expect(model.timezone, 'America/New_York');
      expect(model.businessHours?.start, '09:00');
      expect(model.businessHours?.end, '18:00');
      expect(model.defaultCaseVisibility, 'ORG');
      expect(model.defaultTaskVisibility, true);
      expect(model.website, 'https://acme.law');
      expect(model.address?.city, 'Boston');
      expect(model.address?.country, 'USA');
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);
    });

    test('fromJson handles minimal fields', () {
      final json = {'orgId': 'org-2', 'name': 'Simple Org'};

      final model = OrgSettingsModel.fromJson(json);

      expect(model.plan, 'FREE');
      expect(model.businessHours, isNull);
      expect(model.address, isNull);
    });

    test('toJson round-trip', () {
      final model = OrgSettingsModel(
        orgId: 'org-3',
        name: 'Test',
        plan: 'FREE',
        timezone: 'UTC',
        businessHours: const BusinessHours(start: '08:00', end: '17:00'),
      );
      final json = model.toJson();
      final restored = OrgSettingsModel.fromJson(json);
      expect(restored.orgId, model.orgId);
      expect(restored.name, model.name);
      expect(restored.businessHours?.start, '08:00');
    });
  });

  group('BusinessHours', () {
    test('fromJson defaults', () {
      final model = BusinessHours.fromJson({});
      expect(model.start, '09:00');
      expect(model.end, '17:00');
    });
  });

  group('Address', () {
    test('fromJson handles partial fields', () {
      final model = Address.fromJson({'city': 'NYC', 'country': 'US'});
      expect(model.street, isNull);
      expect(model.city, 'NYC');
      expect(model.country, 'US');
    });
  });
}
