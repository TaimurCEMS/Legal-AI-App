/// Organization model
class OrgModel {
  final String orgId;
  final String name;
  final String? description;
  final String plan;
  final DateTime createdAt;
  final String createdBy;

  OrgModel({
    required this.orgId,
    required this.name,
    this.description,
    required this.plan,
    required this.createdAt,
    required this.createdBy,
  });

  factory OrgModel.fromMap(Map<String, dynamic> map) {
    return OrgModel(
      orgId: map['orgId'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      plan: map['plan'] as String? ?? 'FREE',
      createdAt: (map['createdAt'] as dynamic).toDate(),
      createdBy: map['createdBy'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'name': name,
      'description': description,
      'plan': plan,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }
}

/// Membership model
class MembershipModel {
  final String orgId;
  final String uid;
  final String role;
  final DateTime joinedAt;

  MembershipModel({
    required this.orgId,
    required this.uid,
    required this.role,
    required this.joinedAt,
  });

  factory MembershipModel.fromMap(Map<String, dynamic> map) {
    return MembershipModel(
      orgId: map['orgId'] as String,
      uid: map['uid'] as String,
      role: map['role'] as String,
      joinedAt: (map['joinedAt'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'uid': uid,
      'role': role,
      'joinedAt': joinedAt,
    };
  }
}
