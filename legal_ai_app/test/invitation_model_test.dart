import 'package:flutter_test/flutter_test.dart';
import 'package:legal_ai_app/core/models/invitation_model.dart';

void main() {
  group('InvitationModel', () {
    test('fromJson handles all fields', () {
      final json = {
        'invitationId': 'inv-1',
        'email': 'user@example.com',
        'role': 'LAWYER',
        'status': 'pending',
        'inviteCode': 'ABC123',
        'invitedBy': 'admin-uid',
        'invitedAt': '2026-01-29T10:00:00Z',
        'expiresAt': '2026-02-05T10:00:00Z',
      };

      final model = InvitationModel.fromJson(json);

      expect(model.invitationId, 'inv-1');
      expect(model.email, 'user@example.com');
      expect(model.role, 'LAWYER');
      expect(model.status, 'pending');
      expect(model.inviteCode, 'ABC123');
      expect(model.invitedBy, 'admin-uid');
      expect(model.invitedAt, isNotNull);
      expect(model.expiresAt, isNotNull);
      expect(model.isPending, isTrue);
      expect(model.isExpired, isFalse);
    });

    test('fromJson handles minimal fields with defaults', () {
      final json = {
        'invitationId': 'inv-2',
        'email': 'other@example.com',
      };

      final model = InvitationModel.fromJson(json);

      expect(model.role, 'VIEWER');
      expect(model.status, 'pending');
      expect(model.inviteCode, isNull);
      expect(model.invitedAt, isNull);
    });

    test('isExpired when status is expired', () {
      final model = InvitationModel.fromJson({
        'invitationId': 'inv-3',
        'email': 'e@e.com',
        'status': 'expired',
      });
      expect(model.isExpired, isTrue);
      expect(model.isPending, isFalse);
    });
  });
}
