DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value is Map && value['_seconds'] != null) {
    final seconds = value['_seconds'] as int;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  throw const FormatException('Invalid timestamp format for MemberModel');
}

class MemberModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String role; // 'ADMIN', 'LAWYER', 'PARALEGAL', 'VIEWER'
  final DateTime joinedAt;
  final bool isCurrentUser;

  const MemberModel({
    required this.uid,
    this.email,
    this.displayName,
    required this.role,
    required this.joinedAt,
    required this.isCurrentUser,
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

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      role: json['role'] as String? ?? 'VIEWER',
      joinedAt: _parseTimestamp(json['joinedAt']),
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
      'isCurrentUser': isCurrentUser,
    };
  }
}
