DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for CaseParticipantModel');
}

/// Model representing a participant on a PRIVATE case.
class CaseParticipantModel {
  final String uid;
  final String? displayName;
  final String? email;
  final String role; // "PARTICIPANT" for now
  final DateTime addedAt;
  final String addedBy;

  const CaseParticipantModel({
    required this.uid,
    this.displayName,
    this.email,
    required this.role,
    required this.addedAt,
    required this.addedBy,
  });

  String get displayLabel {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    if (email != null && email!.isNotEmpty) {
      return email!;
    }
    return 'User ${uid.substring(0, 8)}...';
  }

  factory CaseParticipantModel.fromJson(Map<String, dynamic> json) {
    return CaseParticipantModel(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'PARTICIPANT',
      addedAt: _parseTimestamp(json['addedAt']),
      addedBy: json['addedBy'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'role': role,
      'addedAt': addedAt.toIso8601String(),
      'addedBy': addedBy,
    };
  }
}

