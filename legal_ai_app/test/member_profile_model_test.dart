import 'package:flutter_test/flutter_test.dart';
import 'package:legal_ai_app/core/models/member_profile_model.dart';

void main() {
  group('MemberProfileModel', () {
    test('fromJson handles all fields', () {
      final json = {
        'memberUid': 'uid-1',
        'orgId': 'org-1',
        'email': 'lawyer@example.com',
        'displayName': 'Jane Doe',
        'role': 'LAWYER',
        'joinedAt': '2026-01-15T10:00:00Z',
        'bio': 'Senior attorney',
        'title': 'Partner',
        'specialties': ['Corporate', 'M&A'],
        'barAdmissions': [
          {'jurisdiction': 'NY', 'barNumber': '12345', 'admittedYear': 2010},
        ],
        'education': [
          {'institution': 'Harvard Law', 'degree': 'JD', 'year': 2008},
        ],
        'phoneNumber': '+15551234567',
        'photoUrl': 'https://example.com/photo.jpg',
        'isPublic': true,
      };

      final model = MemberProfileModel.fromJson(json);

      expect(model.memberUid, 'uid-1');
      expect(model.orgId, 'org-1');
      expect(model.email, 'lawyer@example.com');
      expect(model.displayName, 'Jane Doe');
      expect(model.role, 'LAWYER');
      expect(model.joinedAt, isNotNull);
      expect(model.bio, 'Senior attorney');
      expect(model.title, 'Partner');
      expect(model.specialties, ['Corporate', 'M&A']);
      expect(model.barAdmissions.length, 1);
      expect(model.barAdmissions.first.jurisdiction, 'NY');
      expect(model.education.length, 1);
      expect(model.education.first.institution, 'Harvard Law');
      expect(model.phoneNumber, '+15551234567');
      expect(model.photoUrl, 'https://example.com/photo.jpg');
      expect(model.isPublic, true);
      expect(model.displayLabel, 'Jane Doe');
    });

    test('displayLabel falls back to email then uid', () {
      final withName = MemberProfileModel.fromJson({
        'memberUid': 'uid-x',
        'orgId': 'org-1',
        'displayName': 'Alice',
        'role': 'VIEWER',
      });
      expect(withName.displayLabel, 'Alice');

      final withEmailOnly = MemberProfileModel.fromJson({
        'memberUid': 'uid-y',
        'orgId': 'org-1',
        'email': 'bob@example.com',
        'role': 'VIEWER',
      });
      expect(withEmailOnly.displayLabel, 'bob@example.com');

      final uidOnly = MemberProfileModel.fromJson({
        'memberUid': 'abcdefghij',
        'orgId': 'org-1',
        'role': 'VIEWER',
      });
      expect(uidOnly.displayLabel, contains('User'));
      expect(uidOnly.displayLabel, contains('...'));
    });

    test('fromJson uses uid when memberUid missing', () {
      final model = MemberProfileModel.fromJson({
        'uid': 'fallback-uid',
        'orgId': 'org-1',
        'role': 'VIEWER',
      });
      expect(model.memberUid, 'fallback-uid');
    });
  });

  group('BarAdmission', () {
    test('fromJson and toJson', () {
      final json = {'jurisdiction': 'CA', 'barNumber': '999', 'admittedYear': 2015};
      final model = BarAdmission.fromJson(json);
      expect(model.jurisdiction, 'CA');
      expect(model.barNumber, '999');
      expect(model.admittedYear, 2015);
      final out = model.toJson();
      expect(out['jurisdiction'], 'CA');
    });
  });

  group('Education', () {
    test('fromJson and toJson', () {
      final json = {'institution': 'Yale', 'degree': 'JD', 'year': 2012};
      final model = Education.fromJson(json);
      expect(model.institution, 'Yale');
      expect(model.degree, 'JD');
      expect(model.year, 2012);
    });
  });
}
