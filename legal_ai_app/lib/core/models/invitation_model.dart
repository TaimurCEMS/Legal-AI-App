/// Invitation model (Slice 15)
class InvitationModel {
  final String invitationId;
  final String email;
  final String role;
  final String status; // pending, accepted, revoked, expired
  final String? inviteCode;
  final String? invitedBy;
  final DateTime? invitedAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final DateTime? revokedAt;
  final String? revokedBy;

  const InvitationModel({
    required this.invitationId,
    required this.email,
    required this.role,
    required this.status,
    this.inviteCode,
    this.invitedBy,
    this.invitedAt,
    this.expiresAt,
    this.acceptedAt,
    this.acceptedBy,
    this.revokedAt,
    this.revokedBy,
  });

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      invitationId: json['invitationId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'VIEWER',
      status: json['status'] as String? ?? 'pending',
      inviteCode: json['inviteCode'] as String?,
      invitedBy: json['invitedBy'] as String?,
      invitedAt: json['invitedAt'] != null
          ? DateTime.tryParse(json['invitedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'] as String)
          : null,
      acceptedBy: json['acceptedBy'] as String?,
      revokedAt: json['revokedAt'] != null
          ? DateTime.tryParse(json['revokedAt'] as String)
          : null,
      revokedBy: json['revokedBy'] as String?,
    );
  }

  bool get isPending => status == 'pending';
  bool get isExpired => status == 'expired';
}
